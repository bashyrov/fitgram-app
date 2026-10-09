import Foundation

// Demo profile snapshots for the in-memory friends backend.
extension InMemoryFriendService {
    /// The seeded demo friends, bundled so the snapshot builder takes them
    /// as one value.
    struct SeedCast {
        let testFriend: PublicProfile
        let marta: PublicProfile
        let ania: PublicProfile
        let kasia: PublicProfile
        let michal: PublicProfile
        let ola: PublicProfile
        let nina: PublicProfile
    }

    struct Stranger {
        let profile: PublicProfile
        let visibility: PrivacySettings.Visibility
        let bio: String
    }

    /// Searchable non-friends: Piotr has an open profile, Zosia a closed one.
    static var strangers: [Stranger] {
        [
            Stranger(
                profile: PublicProfile(
                    id: "friend-piotr-open", displayName: "Piotr Kowalczyk", avatarURL: nil, sharesStreak: true,
                    sharesAchievements: true, currentStreak: 9, achievementCount: 11, username: "piotr.k",
                    isPremium: true),
                visibility: .publicLink,
                bio: TL(
                    pl: "Minus 6 kg od lutego. Biegam 3 razy w tygodniu.",
                    en: "Down 6 kg since February. I run 3 times a week.",
                    uk: "Мінус 6 кг з лютого. Бігаю 3 рази на тиждень.",
                    ru: "Минус 6 кг с февраля. Бегаю 3 раза в неделю.",
                    es: "6 kg menos desde febrero. Corro 3 veces por semana.")),
            Stranger(
                profile: PublicProfile(
                    id: "friend-zosia-private", displayName: "Zosia", avatarURL: nil, sharesStreak: false,
                    sharesAchievements: false, currentStreak: nil, achievementCount: nil, username: "zosia.w"),
                visibility: .friendsOnly,
                bio: ""),
        ]
    }

    // swiftlint:disable:next function_body_length
    static func makeSeedSnapshots(cast: SeedCast, now: Date) -> [String: FriendProfileSnapshot] {
        let testFriend = cast.testFriend
        let marta = cast.marta
        let ania = cast.ania
        let kasia = cast.kasia
        let michal = cast.michal
        let ola = cast.ola
        let nina = cast.nina
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
        ].merging(strangerSnapshots(now: now)) { current, _ in current }
    }

    private static func strangerSnapshots(now: Date) -> [String: FriendProfileSnapshot] {
        Dictionary(
            uniqueKeysWithValues: strangers.map { stranger in
                let profile = stranger.profile
                return (
                    profile.id,
                    FriendProfileSnapshot(
                        id: profile.id, displayName: profile.displayName, username: profile.handle, avatarURL: nil,
                        bio: stranger.bio.isEmpty ? nil : stranger.bio,
                        memberSinceDate: Calendar.current.date(byAdding: .month, value: -5, to: now),
                        currentStreak: profile.currentStreak, level: ProfileLevel(number: 9, label: L("Explorer")),
                        goalLabel: nil, achievements: nil,
                        weeklyStats: WeeklyStats(
                            averageDailyKcal: 2240, totalScans: 19, daysHitGoal: 4,
                            topFoods: [L("Owsianka"), L("Kurczak z kaszą")]),
                        topRecipes: nil, recentEvents: nil, weightKg: nil, heightCm: nil)
                )
            })
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
}
