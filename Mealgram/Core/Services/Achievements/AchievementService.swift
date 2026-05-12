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

        let unlockedIDs = engine.evaluate(meals: meals, streak: streak, alreadyEarned: earnedIDs)
        guard !unlockedIDs.isEmpty else { return [] }

        var unlocked: [AchievementDefinition] = []
        let now = Date()
        for id in unlockedIDs {
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
