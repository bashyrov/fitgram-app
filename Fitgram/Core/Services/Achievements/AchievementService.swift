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
    private let counterStore: AchievementCounterStore

    init(
        container: ModelContainer,
        engine: AchievementEngine = AchievementEngine(),
        counterStore: AchievementCounterStore = AchievementCounterStore()
    ) {
        self.container = container
        self.engine = engine
        self.counterStore = counterStore
    }

    /// Current value of every track metric, for the "Levels" progress view.
    func metrics(forUser userRemoteID: String) -> [AchievementMetric: Int] {
        let context = ModelContext(container)
        let meals = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        guard let inputs = try? engineInputs(for: userRemoteID, earnedCount: 0, in: context) else { return [:] }
        return AchievementEngine.metrics(
            meals: meals,
            dayBuckets: AchievementEngine.groupByDay(meals, calendar: engine.calendar),
            inputs: inputs,
            calendar: engine.calendar,
            now: Date()
        )
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

    /// Goals and lifetime counters the engine needs besides meals + streak.
    private func engineInputs(
        for userRemoteID: String,
        earnedCount: Int,
        in context: ModelContext
    ) throws -> AchievementEngine.Inputs {
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
        var counters = counterStore.counters(forUser: userRemoteID)
        counters.merge(activityCounters(for: userRemoteID, in: context)) { _, new in new }
        counters[.recipesCreated] = recipes.count
        var inputs = AchievementEngine.Inputs(
            proteinGoalGrams: user?.proteinGoalGrams,
            carbsGoalGrams: user?.carbsGoalGrams,
            fatGoalGrams: user?.fatGoalGrams,
            calorieGoalKcal: user?.dailyCalorieGoalKcal,
            hasLoggedWeight: weightCount > 0,
            totalRecipeCooks: totalCooks,
            totalWeightEntries: weightCount,
            totalAchievementsEarned: earnedCount
        )
        inputs.counters = counters
        return inputs
    }

    /// Water, workouts, favourites, goals and coach debriefs.
    private func activityCounters(for userRemoteID: String, in context: ModelContext) -> [AchievementMetric: Int] {
        let calendar = engine.calendar
        let water =
            (try? context.fetch(
                FetchDescriptor<WaterEntry>(predicate: #Predicate { $0.userRemoteID == userRemoteID }))) ?? []
        let waterByDay = Dictionary(grouping: water) { calendar.startOfDay(for: $0.recordedAt) }
            .mapValues { $0.reduce(0) { $0 + $1.milliliters } }
        let workouts =
            (try? context.fetch(
                FetchDescriptor<WorkoutEntry>(predicate: #Predicate { $0.userRemoteID == userRemoteID }))) ?? []
        let favorites =
            (try? context.fetch(
                FetchDescriptor<FavoriteMeal>(predicate: #Predicate { $0.userRemoteID == userRemoteID }))) ?? []
        let goals =
            (try? context.fetch(
                FetchDescriptor<CustomGoal>(predicate: #Predicate { $0.userRemoteID == userRemoteID }))) ?? []
        let debriefs =
            (try? context.fetchCount(
                FetchDescriptor<CoachInsightLog>(predicate: #Predicate { $0.userRemoteID == userRemoteID }))) ?? 0
        return [
            .waterLiters: water.reduce(0) { $0 + $1.milliliters } / 1000,
            .waterDays: waterByDay.values.filter { $0 > 0 }.count,
            .maxWaterDayMl: waterByDay.values.max() ?? 0,
            .workouts: workouts.count,
            .workoutMinutes: workouts.reduce(0) { $0 + $1.durationMinutes },
            .maxWorkoutMinutes: workouts.map(\.durationMinutes).max() ?? 0,
            .kcalBurned: Int(workouts.reduce(0) { $0 + $1.caloriesBurnedKcal }),
            .favoritesSaved: favorites.count,
            .favoriteUses: favorites.reduce(0) { $0 + $1.useCount },
            .goalsCompleted: goals.filter { $0.status == .completed }.count,
            .coachDebriefs: debriefs,
        ]
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

        let inputs = try engineInputs(for: userRemoteID, earnedCount: already.count, in: context)

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
