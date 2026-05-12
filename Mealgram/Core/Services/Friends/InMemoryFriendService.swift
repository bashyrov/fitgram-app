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
        for profile in [kasia, michal, ola] {
            seedProfiles[profile.id] = profile
            seedFriendships.insert(UnorderedPair(userID, profile.id))
        }

        // Mock pending request from a non-friend.
        let nina = PublicProfile(
            id: "friend-nina",
            displayName: "Nina",
            avatarURL: nil,
            sharesStreak: false,
            sharesAchievements: false,
            currentStreak: nil,
            achievementCount: nil
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
                actorID: ola.id,
                actorDisplayName: ola.displayName,
                actorAvatarURL: nil,
                kind: .streakMilestone,
                payload: "Trzy tygodnie z rzędu! 🔥",
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
                payload: "Zdobyła odznakę „Białkowy dzień”.",
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
                payload: "Ugotował „Schabowego z ziemniakami” już 5 razy.",
                createdAt: now().addingTimeInterval(-26 * 60 * 60),
                reactions: [.clap: 1, .flame: 1],
                myReaction: .clap
            ),
        ]

        self.profiles = seedProfiles
        self.friendships = seedFriendships
        self.requests = [pendingRequest]
        self.feed = seedFeed
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
        requests.filter { $0.toUserID == userID && $0.status == .pending }
    }

    func pendingOutgoing(for userID: String) async throws -> [FriendRequest] {
        requests.filter { $0.fromUserID == userID && $0.status == .pending }
    }

    func search(query: String, excluding userID: String) async throws -> [PublicProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty else { return [] }
        return profiles.values
            .filter { $0.id != userID }
            .filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
            .sorted { $0.displayName < $1.displayName }
    }

    func profile(forCode code: String) async throws -> PublicProfile {
        guard let profile = profiles[code] else { throw FriendError.notFound(query: code) }
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
