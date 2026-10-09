import Foundation
import OSLog

/// Process-local friends backend used until a real Supabase project is
/// configured. Seeds three dummy friends + a sample feed so the UI has
/// something to render on a fresh install.
///
/// Thread-safe by virtue of being `@MainActor`. Once `SupabaseFriendService`
/// lands, the only change in the UI layer is a different `FriendService`
/// passed at the composition root.
@MainActor
final class InMemoryFriendService: FriendService {
    private var profiles: [String: PublicProfile]
    private var friendships: Set<UnorderedPair>
    private var requests: [FriendRequest]
    private var feed: [FeedEvent]
    private var profileReactions: [FriendReactionNotification]
    private var blocks: [String: Set<String>] = [:]
    /// Per-friend rich snapshot — produced once at seed time so the
    /// stub returns realistic data on every call.
    private var snapshots: [String: FriendProfileSnapshot] = [:]
    /// Profile visibility per user; missing means `.friendsOnly`.
    private var visibility: [String: PrivacySettings.Visibility] = [:]
    private let now: () -> Date

    // swiftlint:disable function_body_length
    init(seedFor userID: String = "debug-user-001", now: @escaping () -> Date = Date.init) {
        self.now = now
        var seedProfiles: [String: PublicProfile] = [:]
        var seedFeed: [FeedEvent] = []
        var seedFriendships: Set<UnorderedPair> = []

        // Three seeded friends — names match the design brief's PL tone.
        let kasia = PublicProfile(
            id: "friend-kasia",
            displayName: "Kasia",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: 12,
            achievementCount: 5
        )
        let michal = PublicProfile(
            id: "friend-michal",
            displayName: "Michał",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: false,
            currentStreak: 4,
            achievementCount: nil
        )
        let ola = PublicProfile(
            id: "friend-ola",
            displayName: "Ola",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: 21,
            achievementCount: 7
        )
        let ania = PublicProfile(
            id: "friend-ania-demo",
            displayName: "Ania",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: 34,
            achievementCount: 18
        )
        let testFriend = PublicProfile(
            id: "friend-fitgram-test",
            displayName: "Fitgram Test",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: 47,
            achievementCount: 26
        )
        let marta = PublicProfile(
            id: "friend-marta-demo",
            displayName: "Marta Demo",
            avatarURL: nil,
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: 18,
            achievementCount: 14
        )
        let handles: [String: (username: String, premium: Bool)] = [
            testFriend.id: ("fitgram_test", true), marta.id: ("marta_fit", true), ania.id: ("ania.fit", true),
            kasia.id: ("kasia_zdrowo", false), michal.id: ("michal", false), ola.id: ("ola_k", true),
        ]
        for var profile in [testFriend, marta, ania, kasia, michal, ola] {
            profile.username = handles[profile.id]?.username
            profile.isPremium = handles[profile.id]?.premium ?? false
            seedProfiles[profile.id] = profile
            seedFriendships.insert(UnorderedPair(userID, profile.id))
        }
        // Two people who aren't friends yet: one open, one closed profile.
        for stranger in Self.strangers {
            seedProfiles[stranger.profile.id] = stranger.profile
        }

        // Mock pending request from a non-friend.
        let nina = PublicProfile(
            id: "friend-nina",
            displayName: "Nina",
            avatarURL: nil,
            sharesStreak: false,
            sharesAchievements: false,
            currentStreak: nil,
            achievementCount: nil,
            username: "nina"
        )
        seedProfiles[nina.id] = nina

        let pendingRequest = FriendRequest(
            id: UUID(),
            fromUserID: nina.id,
            toUserID: userID,
            status: .pending,
            createdAt: now().addingTimeInterval(-60 * 60)
        )

        seedFeed = [
            FeedEvent(
                id: UUID(),
                actorID: testFriend.id,
                actorDisplayName: testFriend.displayName,
                actorAvatarURL: nil,
                kind: .achievementEarned,
                payload: L("Odblokował serię 47 dni i domknął białko przed kolacją."),
                createdAt: now().addingTimeInterval(-6 * 60),
                reactions: [.sparkles: 5, .heart: 3, .clap: 2],
                myReaction: nil
            ),
            FeedEvent(
                id: UUID(),
                actorID: ania.id,
                actorDisplayName: ania.displayName,
                actorAvatarURL: nil,
                kind: .challengeWon,
                payload: L("Zamknęła tydzień z 6 dniami w celu i idealnym białkiem."),
                createdAt: now().addingTimeInterval(-14 * 60),
                reactions: [.sparkles: 3, .heart: 1],
                myReaction: nil
            ),
            FeedEvent(
                id: UUID(),
                actorID: marta.id,
                actorDisplayName: marta.displayName,
                actorAvatarURL: nil,
                kind: .recipeCooked,
                payload: L("Zrobiła lekki obiad 520 kcal i domknęła wodę przed wieczorem."),
                createdAt: now().addingTimeInterval(-22 * 60),
                reactions: [.heart: 4, .clap: 2],
                myReaction: .heart
            ),
            FeedEvent(
                id: UUID(),
                actorID: ola.id,
                actorDisplayName: ola.displayName,
                actorAvatarURL: nil,
                kind: .streakMilestone,
                payload: L("Trzy tygodnie z rzędu! 🔥"),
                createdAt: now().addingTimeInterval(-30 * 60),
                reactions: [.heart: 2],
                myReaction: nil
            ),
            FeedEvent(
                id: UUID(),
                actorID: kasia.id,
                actorDisplayName: kasia.displayName,
                actorAvatarURL: nil,
                kind: .achievementEarned,
                payload: L("Zdobyła odznakę „Białkowy dzień”."),
                createdAt: now().addingTimeInterval(-3 * 60 * 60),
                reactions: [:],
                myReaction: nil
            ),
            FeedEvent(
                id: UUID(),
                actorID: michal.id,
                actorDisplayName: michal.displayName,
                actorAvatarURL: nil,
                kind: .recipeCooked,
                payload: L("Ugotował „Schabowego z ziemniakami” już 5 razy."),
                createdAt: now().addingTimeInterval(-26 * 60 * 60),
                reactions: [.clap: 1, .flame: 1],
                myReaction: .clap
            ),
        ]

        self.profiles = seedProfiles
        self.friendships = seedFriendships
        self.requests = [pendingRequest]
        self.feed = seedFeed
        self.profileReactions = [
            FriendReactionNotification(
                id: UUID(),
                fromUserID: ania.id,
                fromDisplayName: ania.displayName,
                kind: .sparkles,
                createdAt: now().addingTimeInterval(-8 * 60)
            )
        ]
        self.visibility = Dictionary(uniqueKeysWithValues: Self.strangers.map { ($0.profile.id, $0.visibility) })
        self.snapshots = Self.makeSeedSnapshots(
            cast: SeedCast(
                testFriend: testFriend, marta: marta, ania: ania, kasia: kasia, michal: michal, ola: ola,
                nina: nina
            ),
            now: now()
        )
    }

    // swiftlint:enable function_body_length

    // MARK: - Queries

    func friends(of userID: String) async throws -> [PublicProfile] {
        friendships
            .filter { $0.contains(userID) }
            .compactMap { profiles[$0.other(than: userID)] }
            .sorted { $0.displayName < $1.displayName }
    }

    func pendingIncoming(for userID: String) async throws -> [FriendRequest] {
        requests.filter { $0.toUserID == userID && $0.status == .pending }.map { request in
            var copy = request
            copy.counterpart = profiles[request.fromUserID]
            return copy
        }
    }

    func pendingOutgoing(for userID: String) async throws -> [FriendRequest] {
        requests.filter { $0.fromUserID == userID && $0.status == .pending }.map { request in
            var copy = request
            copy.counterpart = profiles[request.toUserID]
            return copy
        }
    }

    func search(query: String, excluding userID: String) async throws -> [PublicProfile] {
        let trimmed = UsernamePolicy.normalize(query)
        guard !trimmed.isEmpty else { return [] }
        let blocked = blocks[userID] ?? []
        return profiles.values
            .filter { $0.id != userID && !blocked.contains($0.id) }
            .filter {
                $0.displayName.localizedCaseInsensitiveContains(trimmed)
                    || ($0.username?.contains(trimmed) ?? false)
            }
            .sorted { $0.displayName < $1.displayName }
    }

    func profile(forCode code: String) async throws -> PublicProfile {
        if let profile = profiles[code] { return profile }
        let username = UsernamePolicy.normalize(code)
        guard let profile = profiles.values.first(where: { $0.username == username }) else {
            throw FriendError.notFound(query: code)
        }
        return profile
    }

    // MARK: - Mutations

    func sendRequest(from: String, to: String) async throws -> FriendRequest {
        if friendships.contains(UnorderedPair(from, to)) {
            throw FriendError.alreadyFriends
        }
        if requests.contains(where: { $0.fromUserID == from && $0.toUserID == to && $0.status == .pending }) {
            throw FriendError.alreadyRequested
        }
        let request = FriendRequest(
            id: UUID(),
            fromUserID: from,
            toUserID: to,
            status: .pending,
            createdAt: now()
        )
        requests.append(request)
        return request
    }

    func accept(request: FriendRequest, as userID: String) async throws {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else {
            throw FriendError.notFound(query: request.id.uuidString)
        }
        requests[index].status = .accepted
        friendships.insert(UnorderedPair(request.fromUserID, request.toUserID))
        Logger.persistence.notice("Friend request \(request.id) accepted")
    }

    func reject(request: FriendRequest, as userID: String) async throws {
        guard let index = requests.firstIndex(where: { $0.id == request.id }) else {
            throw FriendError.notFound(query: request.id.uuidString)
        }
        requests[index].status = request.fromUserID == userID ? .cancelled : .rejected
    }

    func unfriend(_ friendID: String, as userID: String) async throws {
        friendships.remove(UnorderedPair(userID, friendID))
    }

    func recentFeed(for userID: String, limit: Int) async throws -> [FeedEvent] {
        let friendIDs = try await friends(of: userID).map(\.id)
        return
            feed
            .filter { friendIDs.contains($0.actorID) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func react(to event: FeedEvent, as userID: String, kind: ReactionKind?) async throws -> FeedEvent {
        guard let index = feed.firstIndex(where: { $0.id == event.id }) else {
            throw FriendError.notFound(query: event.id.uuidString)
        }
        var stored = feed[index]
        if let previous = stored.myReaction {
            stored.reactions[previous, default: 0] = max(0, (stored.reactions[previous] ?? 0) - 1)
            if stored.reactions[previous] == 0 { stored.reactions[previous] = nil }
        }
        stored.myReaction = kind
        if let kind {
            stored.reactions[kind, default: 0] += 1
        }
        feed[index] = stored
        return stored
    }

    // MARK: - Profile snapshot + reactions + blocks

    func sendPositiveReaction(
        to userID: String, from viewer: String, intent: PositiveReactionIntent
    ) async throws {
        let sender = profiles[viewer]?.displayName ?? L("Znajomy")
        let kind: ReactionKind =
            switch intent {
            case .encourage: .heart
            case .celebrate: .sparkles
            case .congratulate: .clap
            }
        profileReactions.append(
            FriendReactionNotification(
                id: UUID(),
                fromUserID: viewer,
                fromDisplayName: sender,
                kind: kind,
                createdAt: now()
            )
        )
        Logger.persistence.notice(
            "Positive reaction \(intent.rawValue, privacy: .public) → \(userID, privacy: .private)"
        )
    }

    func incomingReactions(for userID: String, since: Date?, limit: Int) async throws -> [FriendReactionNotification] {
        profileReactions
            .filter { reaction in
                guard let since else { return true }
                return reaction.createdAt > since
            }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }

    func block(_ userID: String, as viewer: String) async throws {
        blocks[viewer, default: []].insert(userID)
        // Block is symmetric for visibility purposes — also unfriend.
        friendships.remove(UnorderedPair(viewer, userID))
    }

    func unblock(_ userID: String, as viewer: String) async throws {
        blocks[viewer]?.remove(userID)
    }

    func blockedUserIDs(for viewer: String) async throws -> Set<String> {
        blocks[viewer] ?? []
    }

    func report(_ userID: String, reason: String, as viewer: String) async throws {
        Logger.persistence.notice(
            "Moderation report from \(viewer, privacy: .private) → \(userID, privacy: .private): \(reason, privacy: .public)"
        )
    }
}

// Profile snapshots + post visibility.
extension InMemoryFriendService {
    func snapshot(forUserID userID: String, viewer: String) async throws -> FriendProfileSnapshot {
        if blocks[viewer]?.contains(userID) == true || blocks[userID]?.contains(viewer) == true {
            throw FriendError.notFound(query: userID)
        }
        guard let snapshot = snapshots[userID] else {
            throw FriendError.notFound(query: userID)
        }
        let profile = profiles[userID]
        let isFriend = friendships.contains(UnorderedPair(viewer, userID))
        let canView: Bool =
            switch visibility[userID] ?? .friendsOnly {
            case .publicLink: true
            case .friendsOnly: isFriend || viewer == userID
            case .privateOnly: viewer == userID
            }
        guard canView else {
            return FriendProfileSnapshot(
                id: snapshot.id, displayName: snapshot.displayName, username: snapshot.username,
                avatarURL: snapshot.avatarURL, bio: nil, memberSinceDate: nil, currentStreak: nil, level: nil,
                goalLabel: nil, achievements: nil, weeklyStats: nil, topRecipes: nil, recentEvents: nil,
                weightKg: nil, heightCm: nil, isPremium: profile?.isPremium ?? false, isRestricted: true
            )
        }
        // Recent events for this friend pulled from the feed so the
        // Activity tab has something to render.
        let events = feed.filter { $0.actorID == userID }.sorted { $0.createdAt > $1.createdAt }
        return FriendProfileSnapshot(
            id: snapshot.id,
            displayName: snapshot.displayName,
            username: snapshot.username,
            avatarURL: snapshot.avatarURL,
            bio: snapshot.bio,
            memberSinceDate: snapshot.memberSinceDate,
            currentStreak: snapshot.currentStreak,
            level: snapshot.level,
            goalLabel: snapshot.goalLabel,
            achievements: snapshot.achievements,
            weeklyStats: snapshot.weeklyStats,
            topRecipes: snapshot.topRecipes,
            recentEvents: events.isEmpty ? nil : events,
            weightKg: snapshot.weightKg,
            heightCm: snapshot.heightCm,
            isPremium: profile?.isPremium ?? false
        )
    }

    /// Whether `viewer` may read `authorID`'s posts (friends, or anyone when
    /// the author's profile is public).
    func canViewPosts(of authorID: String, viewer: String) -> Bool {
        if authorID == viewer { return true }
        if blocks[viewer]?.contains(authorID) == true || blocks[authorID]?.contains(viewer) == true { return false }
        if friendships.contains(UnorderedPair(viewer, authorID)) { return true }
        return visibility[authorID] == .publicLink
    }

    func knows(_ userID: String) -> Bool {
        profiles[userID] != nil
    }
}

/// Helper for symmetric friendship membership.
private struct UnorderedPair: Hashable {
    let first: String
    let second: String

    init(_ lhs: String, _ rhs: String) {
        let sorted = [lhs, rhs].sorted()
        self.first = sorted[0]
        self.second = sorted[1]
    }

    func contains(_ id: String) -> Bool { first == id || second == id }
    func other(than id: String) -> String { first == id ? second : first }
}
