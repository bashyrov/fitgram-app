#if DEBUG
import Foundation
import SwiftData

// Demo recipes for the debug seed.
extension DebugBypass {
    @MainActor
    static func seedRecipes(context: ModelContext) throws {
        let existingCount = try context.fetchCount(FetchDescriptor<Recipe>())
        guard existingCount < 3 else { return }
        [makeBuddhaRecipe(), makePancakesRecipe(), makeSaladRecipe(), makePierogiRecipe()].forEach {
            context.insert($0)
        }
    }

    private static func makeBuddhaRecipe() -> Recipe {
        let buddha = Recipe(
            title: "Tofu Buddha bowl",
            summary: "Light dinner in 25 minutes.",
            servings: 2,
            prepMinutes: 10,
            cookMinutes: 15,
            instructions: [
                "Cube the tofu and pan-fry.",
                "Cook the quinoa.",
                "Chop the vegetables and arrange in a bowl.",
                "Drizzle with tahini sauce.",
            ],
            ingredients: [
                RecipeIngredient(name: "Plain tofu", quantityText: "200 g", quantityGrams: 200),
                RecipeIngredient(name: "Quinoa", quantityText: "100 g", quantityGrams: 100),
                RecipeIngredient(name: "Avocado", quantityText: "1 piece", quantityGrams: 200),
                RecipeIngredient(name: "Carrot", quantityText: "1 piece", quantityGrams: 80),
                RecipeIngredient(name: "Tahini", quantityText: "2 tbsp", quantityGrams: 30),
            ]
        )
        buddha.caloriesPerServing = 520
        buddha.proteinPerServing = 24
        buddha.carbsPerServing = 38
        buddha.fatPerServing = 28
        buddha.cookCount = 7
        buddha.rating = 4.5
        buddha.isFavorite = true
        return buddha
    }

    private static func makePancakesRecipe() -> Recipe {
        let pancakes = Recipe(
            title: "Banana pancakes",
            summary: "Three ingredients, ready in 10 minutes.",
            servings: 1,
            prepMinutes: 3,
            cookMinutes: 7,
            instructions: [
                "Blend banana, eggs and flour.",
                "Fry on the pan one minute each side.",
            ],
            ingredients: [
                RecipeIngredient(name: "Banana", quantityText: "1 piece", quantityGrams: 120),
                RecipeIngredient(name: "Eggs", quantityText: "2 pieces", quantityGrams: 100),
                RecipeIngredient(name: "Oat flour", quantityText: "30 g", quantityGrams: 30),
            ]
        )
        pancakes.caloriesPerServing = 320
        pancakes.proteinPerServing = 16
        pancakes.carbsPerServing = 42
        pancakes.fatPerServing = 9
        pancakes.cookCount = 4
        pancakes.rating = 4.0
        return pancakes
    }

    private static func makeSaladRecipe() -> Recipe {
        let salad = Recipe(
            title: "Greek salad with feta",
            summary: "A classic, with fresh vegetables.",
            servings: 2,
            prepMinutes: 15,
            cookMinutes: 0,
            instructions: [
                "Chop the tomatoes, cucumber and onion.",
                "Add feta, olives, and drizzle with olive oil.",
            ],
            ingredients: [
                RecipeIngredient(name: "Tomatoes", quantityText: "3 pieces", quantityGrams: 300),
                RecipeIngredient(name: "Cucumber", quantityText: "1 piece", quantityGrams: 200),
                RecipeIngredient(name: "Feta", quantityText: "150 g", quantityGrams: 150),
                RecipeIngredient(name: "Olives", quantityText: "60 g", quantityGrams: 60),
                RecipeIngredient(name: "Olive oil", quantityText: "2 tbsp", quantityGrams: 30),
            ]
        )
        salad.caloriesPerServing = 380
        salad.proteinPerServing = 14
        salad.carbsPerServing = 16
        salad.fatPerServing = 30
        salad.cookCount = 2
        return salad
    }

    private static func makePierogiRecipe() -> Recipe {
        let pierogi = Recipe(
            title: "Pierogi ruskie",
            summary: "A classic, made at home.",
            servings: 4,
            prepMinutes: 60,
            cookMinutes: 15,
            instructions: [
                "Knead the dough from flour, water and egg.",
                "Boil the potatoes and blend with cottage cheese.",
                "Form pierogi and drop into boiling water.",
                "Cook 5 minutes after they float.",
            ],
            ingredients: [
                RecipeIngredient(name: "Wheat flour", quantityText: "500 g", quantityGrams: 500),
                RecipeIngredient(name: "Potatoes", quantityText: "400 g", quantityGrams: 400),
                RecipeIngredient(name: "Cottage cheese", quantityText: "250 g", quantityGrams: 250),
                RecipeIngredient(name: "Onion", quantityText: "1 piece", quantityGrams: 100),
                RecipeIngredient(name: "Egg", quantityText: "1 piece", quantityGrams: 50),
            ]
        )
        pierogi.caloriesPerServing = 450
        pierogi.proteinPerServing = 14
        pierogi.carbsPerServing = 76
        pierogi.fatPerServing = 6
        pierogi.cookCount = 12
        pierogi.rating = 5.0
        pierogi.isFavorite = true
        return pierogi
    }
}
#endif
