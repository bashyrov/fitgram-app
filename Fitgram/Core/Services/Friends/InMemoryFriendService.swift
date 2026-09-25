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
        for profile in [testFriend, marta, ania, kasia, michal, ola] {
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
        self.snapshots = Self.makeSeedSnapshots(
            testFriend: testFriend, marta: marta, ania: ania, kasia: kasia, michal: michal, ola: ola,
            nina: nina, now: now()
        )
    }

    private static func makeSeedSnapshots(
        testFriend: PublicProfile, marta: PublicProfile, ania: PublicProfile, kasia: PublicProfile,
        michal: PublicProfile, ola: PublicProfile, nina: PublicProfile,
        now: Date
    ) -> [String: FriendProfileSnapshot] {
        let earlierMember = Calendar.current.date(byAdding: .month, value: -8, to: now) ?? now
        let demoMember = Calendar.current.date(byAdding: .month, value: -14, to: now) ?? now
        let weeklyAnia = WeeklyStats(
            averageDailyKcal: 1745, totalScans: 42, daysHitGoal: 6,
            topFoods: [
                L("Skyr z malinami"),
                L("Łosoś z ryżem"),
                L("Sałatka z kurczakiem"),
            ]
        )
        let weeklyOla = WeeklyStats(
            averageDailyKcal: 1820, totalScans: 31, daysHitGoal: 6,
            topFoods: [
                L("Owsianka"),
                L("Pierogi ruskie"),
                L("Tofu z warzywami"),
            ]
        )
        let weeklyKasia = WeeklyStats(
            averageDailyKcal: 1980, totalScans: 24, daysHitGoal: 5,
            topFoods: [
                L("Schabowy"),
                L("Surówka"),
                L("Sernik"),
            ]
        )
        let weeklyMarta = WeeklyStats(
            averageDailyKcal: 1635, totalScans: 36, daysHitGoal: 5,
            topFoods: [
                L("Jajka z awokado"),
                L("Kurczak z kaszą"),
                L("Twaróg z owocami"),
            ]
        )
        let recipesOla: [PublicRecipeReference] = [
            .init(
                id: UUID(),
                name: L("Buddha bowl z tofu"),
                kcalPerServing: 520,
                cookCount: 7
            ),
            .init(
                id: UUID(),
                name: L("Naleśniki bananowe"),
                kcalPerServing: 320,
                cookCount: 4
            ),
        ]
        let recipesAnia: [PublicRecipeReference] = [
            .init(id: UUID(), name: L("Łosoś teriyaki z ryżem"), kcalPerServing: 610, cookCount: 9),
            .init(id: UUID(), name: L("Proteinowe pankejki"), kcalPerServing: 430, cookCount: 6),
            .init(id: UUID(), name: L("Krem pomidorowy z mozzarellą"), kcalPerServing: 390, cookCount: 4),
        ]
        let recipesTest: [PublicRecipeReference] = [
            .init(id: UUID(), name: L("Citrus chicken bowl"), kcalPerServing: 540, cookCount: 12),
            .init(id: UUID(), name: L("High-protein salmon plate"), kcalPerServing: 620, cookCount: 8),
            .init(id: UUID(), name: L("Evening skyr with berries"), kcalPerServing: 310, cookCount: 15),
        ]
        let recipesMarta: [PublicRecipeReference] = [
            .init(id: UUID(), name: L("Kurczak cytrusowy z kaszą"), kcalPerServing: 520, cookCount: 10),
            .init(id: UUID(), name: L("Omlet białkowy z warzywami"), kcalPerServing: 410, cookCount: 7),
            .init(id: UUID(), name: L("Twaróg z malinami"), kcalPerServing: 280, cookCount: 11),
        ]
        return [
            testFriend.id: FriendProfileSnapshot(
                id: testFriend.id, displayName: testFriend.displayName,
                username: "@fitgram_test", avatarURL: nil,
                bio: L("Testowy znajomy do sprawdzania profilu, reakcji, osiągnięć i rankingu w Fitgram."),
                memberSinceDate: demoMember,
                currentStreak: testFriend.currentStreak,
                level: ProfileLevel(number: 24, label: L("Legend")),
                goalLabel: L("Maintain weight and keep protein high"),
                achievements: Self.demoAchievements(for: testFriend.id, now: now),
                weeklyStats: WeeklyStats(
                    averageDailyKcal: 2110, totalScans: 58, daysHitGoal: 7,
                    topFoods: [
                        L("Citrus chicken bowl"),
                        L("Skyr z malinami"),
                        L("Łosoś z ryżem"),
                    ]
                ),
                topRecipes: recipesTest,
                recentEvents: nil,
                weightKg: 78.2,
                heightCm: 181
            ),
            marta.id: FriendProfileSnapshot(
                id: marta.id, displayName: marta.displayName,
                username: "@marta_fit", avatarURL: nil,
                bio: L("Testowy profil: spokojne odchudzanie, dużo białka i proste obiady bez presji."),
                memberSinceDate: demoMember,
                currentStreak: marta.currentStreak,
                level: ProfileLevel(number: 15, label: L("Pro")),
                goalLabel: L("Lose 5 kg with high protein"),
                achievements: Self.demoAchievements(for: marta.id, now: now),
                weeklyStats: weeklyMarta,
                topRecipes: recipesMarta,
                recentEvents: nil,
                weightKg: 68.6,
                heightCm: 168
            ),
            ania.id: FriendProfileSnapshot(
                id: ania.id, displayName: ania.displayName,
                username: "@ania.fit", avatarURL: nil,
                bio: L("Spokojne tempo, dużo spacerów i kolacje bez chaosu. Cel: czuć się lekko, nie idealnie."),
                memberSinceDate: demoMember,
                currentStreak: ania.currentStreak,
                level: ProfileLevel(number: 16, label: L("Legend")),
                goalLabel: L("Lose 4 kg while keeping strength"),
                achievements: Self.demoAchievements(for: ania.id, now: now),
                weeklyStats: weeklyAnia,
                topRecipes: recipesAnia,
                recentEvents: nil,
                weightKg: 63.4,
                heightCm: 170
            ),
            ola.id: FriendProfileSnapshot(
                id: ola.id, displayName: ola.displayName,
                username: "@ola_k", avatarURL: nil,
                bio: L("Running and pierogi. Started logging in January."),
                memberSinceDate: earlierMember,
                currentStreak: ola.currentStreak,
                level: ProfileLevel(number: 12, label: L("Pro")),
                goalLabel: L("Lose 3 kg"),
                achievements: [],
                weeklyStats: weeklyOla,
                topRecipes: recipesOla,
                recentEvents: nil,
                weightKg: nil,
                heightCm: nil
            ),
            kasia.id: FriendProfileSnapshot(
                id: kasia.id, displayName: kasia.displayName,
                username: "@kasia_zdrowo", avatarURL: nil,
                bio: nil,
                memberSinceDate: earlierMember,
                currentStreak: kasia.currentStreak,
                level: ProfileLevel(number: 8, label: L("Explorer")),
                goalLabel: L("Maintain weight"),
                achievements: [],
                weeklyStats: weeklyKasia,
                topRecipes: [],
                recentEvents: nil,
                weightKg: nil,
                heightCm: nil
            ),
            michal.id: FriendProfileSnapshot(
                id: michal.id, displayName: michal.displayName,
                username: "@michal", avatarURL: nil,
                bio: nil,
                memberSinceDate: earlierMember,
                currentStreak: michal.currentStreak,
                level: nil,
                goalLabel: nil,
                achievements: nil,
                weeklyStats: nil,
                topRecipes: nil,
                recentEvents: nil,
                weightKg: nil,
                heightCm: nil
            ),
            nina.id: FriendProfileSnapshot(
                id: nina.id, displayName: nina.displayName,
                username: "@nina", avatarURL: nil, bio: nil, memberSinceDate: nil,
                currentStreak: nil, level: nil, goalLabel: nil, achievements: nil,
                weeklyStats: nil, topRecipes: nil, recentEvents: nil,
                weightKg: nil, heightCm: nil
            ),
        ]
    }

    private static func demoAchievements(for userID: String, now: Date) -> [Achievement] {
        [
            Achievement(
                userRemoteID: userID,
                kind: "streak.30",
                title: L("30-day rhythm"),
                details: L("Logged meals for 30 days in a row."),
                earnedAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
            ),
            Achievement(
                userRemoteID: userID,
                kind: "protein.week",
                title: L("Protein week"),
                details: L("Hit the protein target for a full week."),
                earnedAt: now.addingTimeInterval(-5 * 24 * 60 * 60)
            ),
            Achievement(
                userRemoteID: userID,
                kind: "challenge.won",
                title: L("Challenge finisher"),
                details: L("Completed a weekly challenge."),
                earnedAt: now.addingTimeInterval(-8 * 24 * 60 * 60)
            ),
        ]
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

    // MARK: - Profile snapshot + reactions + blocks

    func snapshot(forUserID userID: String, viewer: String) async throws -> FriendProfileSnapshot {
        if blocks[viewer]?.contains(userID) == true {
            throw FriendError.notFound(query: userID)
        }
        guard let snapshot = snapshots[userID] else {
            throw FriendError.notFound(query: userID)
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
            heightCm: snapshot.heightCm
        )
    }

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
