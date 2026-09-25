import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class FriendsState {
    enum ConnectionStatus {
        case none
        case outgoing
        case friend
    }

    private(set) var friends: [PublicProfile] = []
    private(set) var incoming: [FriendRequest] = []
    private(set) var outgoing: [FriendRequest] = []
    private(set) var feed: [FeedEvent] = []
    private(set) var searchResults: [PublicProfile] = []
    var searchQuery: String = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let service: any FriendService
    private let notificationCoordinator: NotificationCoordinator?
    let userRemoteID: String

    init(
        service: any FriendService,
        userRemoteID: String,
        notificationCoordinator: NotificationCoordinator? = nil
    ) {
        self.service = service
        self.userRemoteID = userRemoteID
        self.notificationCoordinator = notificationCoordinator
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let friends = service.friends(of: userRemoteID)
            async let incoming = service.pendingIncoming(for: userRemoteID)
            async let outgoing = service.pendingOutgoing(for: userRemoteID)
            async let feed = service.recentFeed(for: userRemoteID, limit: 30)
            self.friends = try await friends
            self.incoming = try await incoming
            self.outgoing = try await outgoing
            self.feed = try await feed
            await notifyIncomingReactionsIfNeeded()
            self.errorMessage = nil
        } catch {
            Logger.persistence.error("Friends refresh failed: \(String(describing: error))")
            errorMessage = String(describing: error)
        }
    }

    private func notifyIncomingReactionsIfNeeded() async {
        guard let notificationCoordinator else { return }
        guard let reactions = try? await service.incomingReactions(for: userRemoteID, since: nil, limit: 12) else {
            return
        }
        await notificationCoordinator.notifyNewFriendReactions(reactions)
    }

    func runSearch() async {
        do {
            let cleaned = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if cleaned.hasPrefix("fitgram://friend/") || UUID(uuidString: cleaned) != nil {
                let profile = try await service.profile(forCode: cleaned)
                searchResults = profile.id == userRemoteID ? [] : [profile]
            } else {
                searchResults = try await service.search(query: searchQuery, excluding: userRemoteID)
            }
        } catch {
            searchResults = []
        }
    }

    func connectionStatus(for profile: PublicProfile) -> ConnectionStatus {
        if friends.contains(where: { $0.id == profile.id }) {
            return .friend
        }
        if outgoing.contains(where: { $0.toUserID == profile.id && $0.status == .pending }) {
            return .outgoing
        }
        return .none
    }

    @discardableResult
    func sendRequest(to profile: PublicProfile) async -> Bool {
        do {
            let request = try await service.sendRequest(from: userRemoteID, to: profile.id)
            if service is InMemoryFriendService {
                try await service.accept(request: request, as: profile.id)
            }
            await refresh()
            errorMessage = nil
            return true
        } catch {
            errorMessage = String(describing: error)
            return false
        }
    }

    func accept(_ request: FriendRequest) async {
        try? await service.accept(request: request, as: userRemoteID)
        await refresh()
    }

    func reject(_ request: FriendRequest) async {
        try? await service.reject(request: request, as: userRemoteID)
        await refresh()
    }

    func unfriend(_ profile: PublicProfile) async {
        try? await service.unfriend(profile.id, as: userRemoteID)
        await refresh()
    }

    func toggleReaction(on event: FeedEvent, kind: ReactionKind) async {
        let next: ReactionKind? = event.myReaction == kind ? nil : kind
        do {
            let updated = try await service.react(to: event, as: userRemoteID, kind: next)
            if let index = feed.firstIndex(where: { $0.id == updated.id }) {
                feed[index] = updated
            }
        } catch {
            // Soft fail.
        }
    }
}
