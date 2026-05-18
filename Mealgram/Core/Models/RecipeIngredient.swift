import Foundation
import SwiftData

/// One ingredient line on a recipe. Free-form `name` so we can capture
/// whatever the source says ("garść natki pietruszki") and try a fuzzy
/// catalog match in a later pass.
@Model
final class RecipeIngredient {
    var id: UUID = UUID()
    var name: String = ""
    var quantityText: String?
    var quantityGrams: Double?
    var note: String?
    var catalogFoodID: UUID?

    var recipe: Recipe?

    init(
        id: UUID = UUID(),
        name: String,
        quantityText: String? = nil,
        quantityGrams: Double? = nil,
        note: String? = nil,
        catalogFoodID: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.quantityText = quantityText
        self.quantityGrams = quantityGrams
        self.note = note
        self.catalogFoodID = catalogFoodID
    }
}
