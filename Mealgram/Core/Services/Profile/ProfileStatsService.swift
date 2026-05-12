import Foundation
import SwiftData

/// Lifetime counters for the Profile screen. Tiny, read-only service —
/// runs four `fetchCount` queries on a fresh context. No caching: the
/// service rebuilds on every Profile appear, which is cheap and avoids
/// staleness after a meal save or recipe cook.
@MainActor
final class ProfileStatsService {
    struct Summary: Equatable, Sendable {
        let totalMeals: Int
        let totalRecipes: Int
        let totalWeightEntries: Int
        let totalAchievements: Int
        let memberSince: Date?
    }

    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func summary(for userRemoteID: String) -> Summary {
        let context = ModelContext(container)
        let mealCount = (try? context.fetchCount(FetchDescriptor<MealEntry>())) ?? 0
        let recipeCount = (try? context.fetchCount(FetchDescriptor<Recipe>())) ?? 0
        let weightCount =
            (try? context.fetchCount(
                FetchDescriptor<WeightEntry>(
                    predicate: #Predicate { $0.userRemoteID == userRemoteID }
                ))) ?? 0
        let achievementCount =
            (try? context.fetchCount(
                FetchDescriptor<Achievement>(
                    predicate: #Predicate { $0.userRemoteID == userRemoteID }
                ))) ?? 0
        let user = try? context.fetch(
            FetchDescriptor<User>(predicate: #Predicate { $0.remoteID == userRemoteID })
        ).first
        return Summary(
            totalMeals: mealCount,
            totalRecipes: recipeCount,
            totalWeightEntries: weightCount,
            totalAchievements: achievementCount,
            memberSince: user?.createdAt
        )
    }
}
