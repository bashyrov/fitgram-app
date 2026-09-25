import Foundation

/// Copy of a recipe's editable fields, taken before an edit so a failed
/// save can put the row back.
struct RecipeRollbackSnapshot {
    let title: String
    let summary: String?
    let servings: Int
    let instructions: [String]
    let caloriesPerServing: Double?
    let proteinPerServing: Double?
    let carbsPerServing: Double?
    let fatPerServing: Double?

    init(_ recipe: Recipe) {
        title = recipe.title
        summary = recipe.summary
        servings = recipe.servings
        instructions = recipe.instructions
        caloriesPerServing = recipe.caloriesPerServing
        proteinPerServing = recipe.proteinPerServing
        carbsPerServing = recipe.carbsPerServing
        fatPerServing = recipe.fatPerServing
    }

    func restore(_ recipe: Recipe) {
        recipe.title = title
        recipe.summary = summary
        recipe.servings = servings
        recipe.instructions = instructions
        recipe.caloriesPerServing = caloriesPerServing
        recipe.proteinPerServing = proteinPerServing
        recipe.carbsPerServing = carbsPerServing
        recipe.fatPerServing = fatPerServing
    }
}
