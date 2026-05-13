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

    /// Duplicates a meal as a fresh entry consumed at `now`. New UUIDs
    /// everywhere; original is untouched. Useful for "I ate the same
    /// thing again" — one tap instead of recreating each FoodItem.
    @discardableResult
    func duplicate(_ source: MealEntry, at now: Date = Date()) throws -> MealEntry {
        let context = ModelContext(container)
        let sourceID = source.id
        // Refetch in this context so we see the latest tags/portion the
        // user just wrote — the `source` parameter may be a stale snapshot
        // bound to a previous context. Standard cross-context pattern.
        let attached =
            try context.fetch(
                FetchDescriptor<MealEntry>(predicate: #Predicate { $0.id == sourceID })
            ).first ?? source
        let copy = MealEntry(
            consumedAt: now,
            mealType: attached.mealType,
            source: attached.source,
            notes: attached.notes,
            // Skip photoFilename — copies shouldn't share the photo file.
            portionMultiplier: attached.portionMultiplier,
            tags: attached.tags,
            items: attached.items.map { item in
                FoodItem(
                    name: item.name,
                    quantityGrams: item.quantityGrams,
                    caloriesKcal: item.caloriesKcal,
                    proteinGrams: item.proteinGrams,
                    carbsGrams: item.carbsGrams,
                    fatGrams: item.fatGrams,
                    fiberGrams: item.fiberGrams,
                    catalogFoodID: item.catalogFoodID,
                    confidence: item.confidence
                )
            }
        )
        context.insert(copy)
        try context.save()
        return copy
    }

    /// Fetches every MealEntry whose consumedAt falls within `[from, to)`.
    /// Used by the activity-heatmap drill-down sheet to render a single
    /// day's meals.
    func meals(in range: Range<Date>) -> [MealEntry] {
        let context = ModelContext(container)
        let lower = range.lowerBound
        let upper = range.upperBound
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= lower && $0.consumedAt < upper },
            sortBy: [SortDescriptor(\MealEntry.consumedAt)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Sweeps the photo directory for filenames no MealEntry references,
    /// deletes them, returns the count. Safe to call from Profile → "Wyczyść
    /// osierocone zdjęcia" — only orphans go.
    @discardableResult
    func cleanupOrphanedPhotos(in store: MealPhotoStore) -> Int {
        let context = ModelContext(container)
        let allMeals = (try? context.fetch(FetchDescriptor<MealEntry>())) ?? []
        let inUse = Set(allMeals.compactMap(\.photoFilename))
        let orphans = store.allFilenames().filter { !inUse.contains($0) }
        for filename in orphans {
            store.delete(filename: filename)
        }
        return orphans.count
    }

    /// Returns true when no MealEntry references the given photo
    /// filename. The MealDetailSheet's deferred-cleanup path uses this
    /// just before deleting the file — protects against the undo
    /// banner restoring a meal whose photo would otherwise vanish.
    func photoIsOrphaned(filename: String) -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.photoFilename == filename }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count == 0
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

    /// Updates the free-text notes on an existing meal. Empty / whitespace
    /// stored as nil so we don't accumulate ghost-empty rows.
    func updateNotes(_ meal: MealEntry, notes: String) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            throw MealRepositoryError.notFound
        }
        let cleaned = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        attached.notes = cleaned.isEmpty ? nil : cleaned
        attached.updatedAt = Date()
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

    /// Returns every tag the user has ever attached to a meal, ordered
    /// by frequency desc (most-used first), unique. Used to power the
    /// tag-autocomplete strip on MealDetailSheet.
    func knownTags() throws -> [String] {
        let context = ModelContext(container)
        let meals = try context.fetch(FetchDescriptor<MealEntry>())
        var counts: [String: Int] = [:]
        for meal in meals {
            for tag in meal.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts.sorted { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value > rhs.value }
            return lhs.key < rhs.key
        }.map(\.key)
    }

    /// Updates the portion multiplier on an existing meal. Same refetch
    /// pattern to dodge cross-context surprises.
    /// Edits the consumedAt timestamp on an existing meal so users can
    /// correct entries logged at the wrong time (or back-date a meal eaten
    /// yesterday). Clamped at "not in the future" — anything past now
    /// snaps to now.
    func updateConsumedAt(_ meal: MealEntry, to date: Date, now: Date = Date()) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            throw MealRepositoryError.notFound
        }
        attached.consumedAt = min(date, now)
        attached.updatedAt = now
        try context.save()
    }

    /// 1–5 star meal rating; nil clears it. Out-of-range values clamp.
    func updateRating(_ meal: MealEntry, rating: Int?) throws {
        let context = ModelContext(container)
        let mealID = meal.id
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.id == mealID }
        )
        guard let attached = try context.fetch(descriptor).first else {
            throw MealRepositoryError.notFound
        }
        attached.rating = rating.map { max(1, min(5, $0)) }
        attached.updatedAt = Date()
        try context.save()
    }

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
