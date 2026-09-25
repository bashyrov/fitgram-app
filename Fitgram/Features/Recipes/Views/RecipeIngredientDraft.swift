import Foundation

/// One ingredient row in the recipe portion sheet, with per-100 g macros.
struct RecipeIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantityGrams: Double
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double

    init(
        name: String,
        quantityGrams: Double,
        caloriesKcalPer100g: Double = 0,
        proteinGramsPer100g: Double = 0,
        carbsGramsPer100g: Double = 0,
        fatGramsPer100g: Double = 0
    ) {
        self.name = name
        self.quantityGrams = quantityGrams
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
    }

    private var factor: Double { quantityGrams / 100 }
    var caloriesKcal: Double { caloriesKcalPer100g * factor }
    var proteinGrams: Double { proteinGramsPer100g * factor }
    var carbsGrams: Double { carbsGramsPer100g * factor }
    var fatGrams: Double { fatGramsPer100g * factor }
}

extension RecipeIngredientDraft {
    /// Rows from the recipe's ingredients, or one row carrying the
    /// per-serving macros when the recipe has no ingredient list.
    static func initialDrafts(for recipe: Recipe) -> [RecipeIngredientDraft] {
        let servingCount = max(Double(recipe.servings), 1)
        if !recipe.ingredients.isEmpty {
            return recipe.ingredients.map { ingredient in
                let grams = ingredient.quantityGrams ?? 100
                return RecipeIngredientDraft(name: ingredient.name, quantityGrams: grams)
            }
        }
        return [
            RecipeIngredientDraft(
                name: recipe.title,
                quantityGrams: 100,
                caloriesKcalPer100g: recipe.caloriesPerServing ?? 0,
                proteinGramsPer100g: recipe.proteinPerServing ?? 0,
                carbsGramsPer100g: recipe.carbsPerServing ?? 0,
                fatGramsPer100g: recipe.fatPerServing ?? 0
            )
        ].map { draft in
            var adjusted = draft
            adjusted.quantityGrams = max(100, 100 / servingCount)
            return adjusted
        }
    }
}
