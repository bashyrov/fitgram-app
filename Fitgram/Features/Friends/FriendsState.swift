import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class FriendsState {
    enum ConnectionStatus {
        case none
        case outgoing
        case incoming
        case friend
    }

    private(set) var friends: [PublicProfile] = []
    private(set) var incoming: [FriendRequest] = []
    private(set) var outgoing: [FriendRequest] = []
    private(set) var posts: [SocialPost] = []
    private(set) var postsLoaded = false
    private(set) var searchResults: [PublicProfile] = []
    var searchQuery: String = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    /// The signed-in user's chosen username (without "@"), nil until picked.
    private(set) var myUsername: String?
    private(set) var needsUsername = false
    var myDisplayName: String = ""
    private(set) var isPremium = false
    private(set) var postsPublishedToday = 0

    let service: any FriendService
    let postService: any PostService
    let socialProfile: any SocialProfileServing
    private let notificationCoordinator: NotificationCoordinator?
    private let achievementCounters: AchievementCounterStore
    private let calendar: Calendar
    let userRemoteID: String

    init(
        service: any FriendService,
        postService: (any PostService)? = nil,
        socialProfile: (any SocialProfileServing)? = nil,
        userRemoteID: String,
        notificationCoordinator: NotificationCoordinator? = nil,
        achievementCounters: AchievementCounterStore = AchievementCounterStore(),
        calendar: Calendar = .current
    ) {
        self.service = service
        self.postService = postService ?? PostServiceFactory.make(for: service)
        self.socialProfile = socialProfile ?? SocialProfileServiceFactory.make()
        self.userRemoteID = userRemoteID
        self.notificationCoordinator = notificationCoordinator
        self.achievementCounters = achievementCounters
        self.calendar = calendar
    }

    /// The viewer as a post author.
    var me: PublicProfile {
        PublicProfile(
            id: userRemoteID,
            displayName: myDisplayName.nilIfBlank ?? myUsername.map { "@\($0)" } ?? "Fitgram",
            avatarURL: nil,
            sharesStreak: false,
            sharesAchievements: false,
            currentStreak: nil,
            achievementCount: nil,
            username: myUsername,
            isPremium: isPremium
        )
    }

    var postsLeftToday: Int { max(0, PostLimits.dailyMax - postsPublishedToday) }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let friends = service.friends(of: userRemoteID)
            async let incoming = service.pendingIncoming(for: userRemoteID)
            async let outgoing = service.pendingOutgoing(for: userRemoteID)
            self.friends = try await friends
            self.incoming = try await incoming
            self.outgoing = try await outgoing
            achievementCounters.recordAtLeast(self.friends.count, for: .friends, user: userRemoteID)
            await notificationCoordinator?.notifyNewFriendRequests(self.incoming)
            self.errorMessage = nil
        } catch {
            Logger.persistence.error("Friends refresh failed: \(String(describing: error))")
            errorMessage = String(describing: error)
        }
        await refreshPosts()
    }

    func refreshPosts() async {
        do {
            posts = try await postService.feed(
                authorIDs: friends.map(\.id) + [userRemoteID], viewer: userRemoteID, limit: 50)
            postsPublishedToday = try await postService.postCount(by: userRemoteID, on: Date(), calendar: calendar)
        } catch {
            Logger.persistence.error("Posts refresh failed: \(String(describing: error))")
        }
        postsLoaded = true
    }

    // MARK: - Identity

    /// Pulls the chosen username + privacy from the backend. A username typed
    /// in onboarding while offline is claimed here.
    func loadIdentity(localUsername: String?) async -> String? {
        if let remote = try? await socialProfile.chosenUsername(userID: userRemoteID) {
            myUsername = remote
            needsUsername = false
            return remote
        }
        if let localUsername, (try? await claimUsername(localUsername)) != nil {
            return localUsername
        }
        needsUsername = myUsername == nil
        return myUsername
    }

    func claimUsername(_ username: String) async throws {
        let name = UsernamePolicy.normalize(username)
        try await socialProfile.claimUsername(name, displayName: myDisplayName, userID: userRemoteID)
        myUsername = name
        needsUsername = false
    }

    /// Publishes the Premium mark and display name next to the username.
    func setPremium(_ isPremium: Bool) async {
        self.isPremium = isPremium
        await socialProfile.syncProfile(isPremium: isPremium, displayName: myDisplayName, userID: userRemoteID)
    }

    // MARK: - Search + requests

    func runSearch() async {
        do {
            let cleaned = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("fitgram://friend/") || UUID(uuidString: cleaned) != nil {
                let profile = try await service.profile(forCode: cleaned)
                searchResults = profile.id == userRemoteID ? [] : [profile]
            } else {
                searchResults = try await service.search(query: cleaned, excluding: userRemoteID)
            }
        } catch {
            searchResults = []
        }
    }

    func connectionStatus(for profileID: String) -> ConnectionStatus {
        if friends.contains(where: { $0.id == profileID }) {
            return .friend
        }
        if outgoing.contains(where: { $0.toUserID == profileID && $0.status == .pending }) {
            return .outgoing
        }
        if incoming.contains(where: { $0.fromUserID == profileID && $0.status == .pending }) {
            return .incoming
        }
        return .none
    }

    func connectionStatus(for profile: PublicProfile) -> ConnectionStatus {
        connectionStatus(for: profile.id)
    }

    @discardableResult
    func sendRequest(to profileID: String) async -> Bool {
        do {
            let request = try await service.sendRequest(from: userRemoteID, to: profileID)
            achievementCounters.increment(.friendRequestsSent, user: userRemoteID)
            if service is InMemoryFriendService {
                try await service.accept(request: request, as: profileID)
            }
            await refresh()
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    @discardableResult
    func sendRequest(to profile: PublicProfile) async -> Bool {
        await sendRequest(to: profile.id)
    }

    func accept(_ request: FriendRequest) async {
        try? await service.accept(request: request, as: userRemoteID)
        await refresh()
    }

    func reject(_ request: FriendRequest) async {
        try? await service.reject(request: request, as: userRemoteID)
        await refresh()
    }

    /// Accept / decline from a profile opened via search.
    func respondToRequest(from profileID: String, accept: Bool) async {
        guard let request = incoming.first(where: { $0.fromUserID == profileID }) else { return }
        if accept {
            await self.accept(request)
        } else {
            await reject(request)
        }
    }

    func cancelRequest(to profileID: String) async {
        guard let request = outgoing.first(where: { $0.toUserID == profileID }) else { return }
        try? await service.reject(request: request, as: userRemoteID)
        await refresh()
    }

    func unfriend(_ profileID: String) async {
        try? await service.unfriend(profileID, as: userRemoteID)
        await refresh()
    }

    func unfriend(_ profile: PublicProfile) async {
        await unfriend(profile.id)
    }

    // MARK: - Posts

    /// Optimistic like / unlike; rolls back if the backend refuses.
    func toggleLike(_ post: SocialPost) async {
        let liked = !post.isLikedByMe
        apply(liked: liked, to: post.id)
        do {
            try await postService.setLiked(liked, postID: post.id, viewer: userRemoteID)
            if liked { achievementCounters.increment(.reactionsGiven, user: userRemoteID) }
        } catch {
            apply(liked: !liked, to: post.id)
        }
    }

    private func apply(liked: Bool, to postID: UUID) {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { return }
        guard posts[index].isLikedByMe != liked else { return }
        posts[index].isLikedByMe = liked
        posts[index].likeCount = max(0, posts[index].likeCount + (liked ? 1 : -1))
    }

    func publish(_ draft: PostDraft) async throws {
        let post = try await postService.create(draft, as: me, isPremium: isPremium)
        posts.insert(post, at: 0)
        postsPublishedToday += 1
    }

    func deletePost(_ post: SocialPost) async {
        do {
            try await postService.delete(postID: post.id, as: userRemoteID)
            posts.removeAll { $0.id == post.id }
            if calendar.isDateInToday(post.createdAt) {
                postsPublishedToday = max(0, postsPublishedToday - 1)
            }
        } catch {
            Logger.persistence.error("Post delete failed: \(String(describing: error))")
        }
    }

    func posts(by authorID: String) async -> AuthorPosts {
        (try? await postService.posts(by: authorID, viewer: userRemoteID)) ?? AuthorPosts(posts: [], isHidden: false)
    }

    func setLiked(_ liked: Bool, postID: UUID) async -> Bool {
        do {
            try await postService.setLiked(liked, postID: postID, viewer: userRemoteID)
            apply(liked: liked, to: postID)
            return true
        } catch {
            return false
        }
    }
}
