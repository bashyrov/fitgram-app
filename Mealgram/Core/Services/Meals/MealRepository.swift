import Foundation
import OSLog
import SwiftData

/// Read/mutate ops on `MealEntry` beyond the initial save. The save path
/// already lives in `SwiftDataMealSaver` (single side-effect spine via
/// `ChainedMealSaver`); deletes + portion edits go through here so the
/// dashboard refresh story stays explicit at the call site.
@MainActor
final class MealRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// Cross-context-safe delete — refetches by id in a fresh context before
    /// calling `context.delete`. See RecipeRepository.delete for the same
    /// pattern + reasoning.
    func delete(_ meal: MealEntry) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            Logger.persistence.notice("Meal \(mealID) already gone — delete is a no-op")
            return
        }
        context.delete(attached)
        try context.save()
    }

    /// Updates the tags on an existing meal. Same refetch pattern. Tags
    /// are trimmed + lower-cased + deduped before saving so the user can
    /// type "Restaurant" and "restaurant" without ending up with two
    /// entries.
    func updateTags(_ meal: MealEntry, tags: [String]) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            throw MealRepositoryError.notFound
        }
        var seen: Set<String> = []
        attached.tags = tags.compactMap { raw in
            let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !cleaned.isEmpty, !seen.contains(cleaned) else { return nil }
            seen.insert(cleaned)
            return cleaned
        }
        attached.updatedAt = Date()
        try context.save()
    }

    /// Updates the portion multiplier on an existing meal. Same refetch
    /// pattern to dodge cross-context surprises.
    func updatePortion(_ meal: MealEntry, multiplier: Double) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            throw MealRepositoryError.notFound
        }
        attached.portionMultiplier = max(0.05, multiplier)
        attached.updatedAt = Date()
        try context.save()
    }
}

enum MealRepositoryError: Error, Equatable {
    case notFound
}
