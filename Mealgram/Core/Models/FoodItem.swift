import Foundation
import SwiftData

/// A single line in a meal — e.g. "200 g kurczak z grilla". Snapshots the
/// nutrition values at the time of logging (not a live reference to `Food`)
/// so historical data remains stable when the catalog updates later.
@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var quantityGrams: Double = 0
    var caloriesKcal: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?

    /// Soft pointer to the catalog row this item was derived from. Optional
    /// — manual entries and one-off photo scans may not match any catalog.
    var catalogFoodID: UUID?
    var confidence: Double?

    var meal: MealEntry?

    init(
        id: UUID = UUID(),
        name: String,
        quantityGrams: Double,
        caloriesKcal: Double,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double? = nil,
        catalogFoodID: UUID? = nil,
        confidence: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.quantityGrams = quantityGrams
        self.caloriesKcal = caloriesKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.catalogFoodID = catalogFoodID
        self.confidence = confidence
    }
}

extension FoodItem {
    /// Convenience constructor for adding a catalog Food at a given portion.
    static func from(food: Food, quantityGrams: Double, confidence: Double? = nil) -> FoodItem {
        let factor = quantityGrams / 100.0
        return FoodItem(
            name: food.name,
            quantityGrams: quantityGrams,
            caloriesKcal: food.caloriesKcalPer100g * factor,
            proteinGrams: food.proteinGramsPer100g * factor,
            carbsGrams: food.carbsGramsPer100g * factor,
            fatGrams: food.fatGramsPer100g * factor,
            fiberGrams: food.fiberGramsPer100g.map { $0 * factor },
            catalogFoodID: food.id,
            confidence: confidence
        )
    }
}
