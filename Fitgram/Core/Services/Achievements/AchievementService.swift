import Foundation
import OSLog
import SwiftData

/// Façade in front of `AchievementEngine` + SwiftData. The save path calls
/// `evaluate(forUser:)` after a meal is committed; UI surfaces the
/// returned unlocks via a banner. Idempotent — running it twice in the
/// same second returns no duplicates.
@MainActor
final class AchievementService {
    private let container: ModelContainer
    private let engine: AchievementEngine

    init(container: ModelContainer, engine: AchievementEngine = AchievementEngine()) {
        self.container = container
        self.engine = engine
    }

    /// Evaluates the catalog and persists newly-earned rows for `userRemoteID`.
    /// Returns the unlocked definitions so callers can render a banner.
    @discardableResult
    func evaluate(forUser userRemoteID: String) throws -> [AchievementDefinition] {
        try evaluate(forUser: userRemoteID, afterSavingMealID: nil)
    }

    /// Save-path evaluation: only grants achievements whose predicate
    /// changed because of the meal that has just been saved. This avoids
    /// dumping a historical backlog of 25/50/100-meal badges after one
    /// ordinary entry when older data already existed on the device.
    @discardableResult
    func evaluateAfterSaving(
        meal savedMeal: MealEntry,
        forUser userRemoteID: String
    ) throws -> [AchievementDefinition] {
        try evaluate(forUser: userRemoteID, afterSavingMealID: savedMeal.id)
    }

    private func evaluate(
        forUser userRemoteID: String,
        afterSavingMealID savedMealID: UUID?
    ) throws -> [AchievementDefinition] {
        let context = ModelContext(container)

        let alreadyDescriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        let already = try context.fetch(alreadyDescriptor)
        let earnedIDs = Set(already.map(\.kind))

        // MealEntry has no userRemoteID yet (single-user installs). Pull
        // every entry on the device — once multi-user lands the predicate
        // will move into the descriptor.
        let meals = try context.fetch(
            FetchDescriptor<MealEntry>(
                sortBy: [SortDescriptor(\MealEntry.consumedAt)]
            ))

        let streakDescriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        let streak = try context.fetch(streakDescriptor).first

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        let user = try context.fetch(userDescriptor).first

        let weightDescriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        let weightCount = (try? context.fetchCount(weightDescriptor)) ?? 0

        let recipes = (try? context.fetch(FetchDescriptor<Recipe>())) ?? []
        let totalCooks = recipes.reduce(0) { $0 + $1.cookCount }

        let inputs = AchievementEngine.Inputs(
            proteinGoalGrams: user?.proteinGoalGrams,
            carbsGoalGrams: user?.carbsGoalGrams,
            fatGoalGrams: user?.fatGoalGrams,
            calorieGoalKcal: user?.dailyCalorieGoalKcal,
            hasLoggedWeight: weightCount > 0,
            totalRecipeCooks: totalCooks,
            totalWeightEntries: weightCount,
            totalAchievementsEarned: already.count
        )

        let unlockedIDs = engine.evaluate(
            meals: meals, streak: streak,
            alreadyEarned: earnedIDs, inputs: inputs
        )
        let idsToGrant: [String]
        if let savedMealID {
            let previousMeals = meals.filter { $0.id != savedMealID }
            let previousUnlockedIDs = Set(
                engine.evaluate(
                    meals: previousMeals, streak: streak,
                    alreadyEarned: earnedIDs, inputs: inputs
                )
            )
            idsToGrant = unlockedIDs.filter { !previousUnlockedIDs.contains($0) }
        } else {
            idsToGrant = unlockedIDs
        }
        guard !idsToGrant.isEmpty else { return [] }

        var unlocked: [AchievementDefinition] = []
        let now = Date()
        for id in idsToGrant {
            guard let definition = AchievementCatalog.definition(for: id) else { continue }
            let row = Achievement(
                userRemoteID: userRemoteID,
                kind: definition.id,
                title: definition.title,
                details: definition.summary,
                earnedAt: now
            )
            context.insert(row)
            unlocked.append(definition)
            Logger.persistence.notice("Granted achievement \(definition.id, privacy: .public)")
        }
        try context.save()
        return unlocked
    }

    /// All earned achievements for the user, newest first. Used by the
    /// Profile grid.
    func earned(forUser userRemoteID: String) throws -> [Achievement] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Achievement>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID },
            sortBy: [SortDescriptor(\Achievement.earnedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
}
