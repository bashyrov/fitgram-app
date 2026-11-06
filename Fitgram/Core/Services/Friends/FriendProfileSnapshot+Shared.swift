import Foundation

extension FriendProfileSnapshot {
    /// A visible friend's profile: identity from `public_profiles`, the rest
    /// from what the owner shares (`profile_shares`), with labels in the
    /// viewer's language.
    init(profile: PublicProfile, row: PublicProfileRow, shared: SharedProfile?, recentEvents: [FeedEvent]) {
        self.init(
            id: profile.id,
            displayName: profile.displayName,
            username: row.username.isEmpty ? nil : "@\(row.username)",
            avatarURL: profile.avatarURL,
            bio: row.bio?.nilIfBlank,
            memberSinceDate: row.createdAt?.supabaseDate,
            currentStreak: shared?.streak,
            level: shared?.level.map { ProfileLevel(number: $0, label: AchievementXP.rankTitle(forLevel: $0)) },
            goalLabel: shared?.goal.map {
                ProfileGoalLabel.text(
                    kind: GoalKind(rawValue: $0.kind) ?? .justTracking, targetKg: $0.targetKg, startKg: $0.startKg,
                    endDate: $0.endDate)
            },
            achievements: shared?.achievementKinds.map { kinds in
                kinds.map {
                    Achievement(userRemoteID: profile.id, kind: $0, title: Self.badgeTitle($0), details: "")
                }
            },
            weeklyStats: shared?.weekly.map {
                WeeklyStats(
                    averageDailyKcal: $0.averageDailyKcal, totalScans: $0.totalScans, daysHitGoal: $0.daysHitGoal,
                    topFoods: $0.topFoods)
            },
            topRecipes: shared?.recipes.map { recipes in
                recipes.map {
                    PublicRecipeReference(
                        id: $0.id, name: $0.name, kcalPerServing: $0.kcalPerServing, cookCount: $0.cookCount)
                }
            },
            recentEvents: recentEvents,
            weightKg: shared?.weightKg,
            heightCm: shared?.heightCm,
            isPremium: profile.isPremium
        )
    }

    private static func badgeTitle(_ kind: String) -> String {
        AchievementCatalog.all.first { $0.id == kind }?.title ?? kind
    }
}
