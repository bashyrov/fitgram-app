import Foundation

/// Value-type capture of a `MealEntry` and its `FoodItem`s for undo.
/// Held in memory between the delete and the time-bound "Cofnij" banner.
/// Restoring goes through the normal `MealSaving` pipeline, so a fresh
/// `MealEntry` (new UUIDs) gets created and side-effects re-fire.
struct MealEntrySnapshot: Equatable, Sendable, Identifiable {
    struct Item: Equatable, Sendable {
        let name: String
        let quantityGrams: Double
        let caloriesKcal: Double
        let proteinGrams: Double
        let carbsGrams: Double
        let fatGrams: Double
        let fiberGrams: Double?
        let catalogFoodID: UUID?
        let confidence: Double?
    }

    let id: UUID
    let consumedAt: Date
    let mealType: MealType
    let source: MealSource
    let notes: String?
    let photoFilename: String?
    let portionMultiplier: Double
    let items: [Item]
}

extension MealEntrySnapshot {
    /// Builds a snapshot from a live `@Model` — call this *before* you
    /// hand the entry to `MealRepository.delete` (after delete the items
    /// relationship may be invalid).
    static func capture(from meal: MealEntry) -> MealEntrySnapshot {
        MealEntrySnapshot(
            id: UUID(),
            consumedAt: meal.consumedAt,
            mealType: meal.mealType,
            source: meal.source,
            notes: meal.notes,
            photoFilename: meal.photoFilename,
            portionMultiplier: meal.portionMultiplier,
            items: meal.items.map { item in
                Item(
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
    }

    /// Rebuilds a fresh `MealEntry` from the snapshot. Caller is
    /// responsible for handing it to `MealSaving`.
    func makeEntry() -> MealEntry {
        let entry = MealEntry(
            consumedAt: consumedAt,
            mealType: mealType,
            source: source,
            notes: notes,
            photoFilename: photoFilename,
            portionMultiplier: portionMultiplier,
            items: items.map {
                FoodItem(
                    name: $0.name,
                    quantityGrams: $0.quantityGrams,
                    caloriesKcal: $0.caloriesKcal,
                    proteinGrams: $0.proteinGrams,
                    carbsGrams: $0.carbsGrams,
                    fatGrams: $0.fatGrams,
                    fiberGrams: $0.fiberGrams,
                    catalogFoodID: $0.catalogFoodID,
                    confidence: $0.confidence
                )
            }
        )
        return entry
    }
}
