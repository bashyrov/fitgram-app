import Foundation
import OSLog
import SwiftData

/// Reads + writes saved recipes. Free-form for now — Phase 3 wires in the
/// URL parser (Schema.org Recipe extraction via Worker) and the AI-driven
/// modifications engine. This repo just provides the CRUD surface the UI
/// needs and a `cook(...)` helper that produces the MealEntry value.
@MainActor
final class RecipeRepository {
    private let container: ModelContainer
    private let spotlightIndexer: RecipeSpotlightIndexing?

    init(container: ModelContainer, spotlightIndexer: RecipeSpotlightIndexing? = nil) {
        self.container = container
        self.spotlightIndexer = spotlightIndexer
    }

    func all(sortedByCookCount: Bool = false) throws -> [Recipe] {
        let context = ModelContext(container)
        let sortDescriptors: [SortDescriptor<Recipe>]
        if sortedByCookCount {
            sortDescriptors = [
                SortDescriptor(\Recipe.cookCount, order: .reverse),
                SortDescriptor(\Recipe.title),
            ]
        } else {
            sortDescriptors = [SortDescriptor(\Recipe.createdAt, order: .reverse)]
        }
        return try context.fetch(FetchDescriptor<Recipe>(sortBy: sortDescriptors))
    }

    /// Inserts a brand-new recipe.
    @discardableResult
    func create(_ recipe: Recipe) throws -> Recipe {
        let context = ModelContext(container)
        context.insert(recipe)
        try context.save()
        Logger.persistence.notice("Created recipe \(recipe.id, privacy: .public)")
        spotlightIndexer?.index(recipe)
        return recipe
    }

    /// Updates an existing recipe in place — caller already mutated the
    /// SwiftData entity; we just ensure the save is flushed.
    func save(_ recipe: Recipe) throws {
        recipe.updatedAt = Date()
        let context = ModelContext(container)
        try context.save()
        spotlightIndexer?.index(recipe)
    }

    func delete(_ recipe: Recipe) throws {
        // The caller's recipe lives in another `ModelContext`; re-fetch
        // by id in our context so the delete actually applies.
        let context = ModelContext(container)
        let recipeID = recipe.id
        let descriptor = FetchDescriptor<Recipe>(
            predicate: #Predicate { $0.id == recipeID }
        )
        if let stored = try context.fetch(descriptor).first {
            context.delete(stored)
            try context.save()
            spotlightIndexer?.remove(recipeID: recipeID)
        }
    }

    /// Duplicates the recipe into a fresh row with " (kopia)" appended
    /// to the title. New UUIDs everywhere; cookCount + isFavorite reset
    /// since the copy is a new dish in the user's mind.
    @discardableResult
    func duplicate(_ source: Recipe) throws -> Recipe {
        let context = ModelContext(container)
        let sourceID = source.id
        let attached =
            (try? context.fetch(
                FetchDescriptor<Recipe>(predicate: #Predicate { $0.id == sourceID })
            ).first) ?? source
        let copy = Recipe(
            title: attached.title + " (kopia)",
            summary: attached.summary,
            sourceURL: attached.sourceURL,
            servings: attached.servings,
            prepMinutes: attached.prepMinutes,
            cookMinutes: attached.cookMinutes,
            instructions: attached.instructions,
            ingredients: attached.ingredients.map {
                RecipeIngredient(
                    name: $0.name,
                    quantityText: $0.quantityText,
                    quantityGrams: $0.quantityGrams,
                    note: $0.note,
                    catalogFoodID: $0.catalogFoodID
                )
            }
        )
        copy.caloriesPerServing = attached.caloriesPerServing
        copy.proteinPerServing = attached.proteinPerServing
        copy.carbsPerServing = attached.carbsPerServing
        copy.fatPerServing = attached.fatPerServing
        context.insert(copy)
        try context.save()
        spotlightIndexer?.index(copy)
        return copy
    }

    /// One-shot reindex of every recipe. Called at launch so cold installs
    /// + post-restore states have a populated Spotlight index without
    /// waiting for the user to touch each recipe again.
    func reindexSpotlight() throws {
        guard let spotlightIndexer else { return }
        let recipes = try all()
        spotlightIndexer.indexAll(recipes)
    }

    /// Produces a `MealEntry` for one serving of the recipe and bumps the
    /// recipe's cook counter. The recipe row itself stays in the catalogue.
    func cook(_ recipe: Recipe, servings: Double = 1) -> MealEntry {
        let caloriesPerServing = recipe.caloriesPerServing ?? 0
        let proteinPerServing = recipe.proteinPerServing ?? 0
        let carbsPerServing = recipe.carbsPerServing ?? 0
        let fatPerServing = recipe.fatPerServing ?? 0
        let item = FoodItem(
            name: recipe.title,
            quantityGrams: max(servings * 100, 100),
            caloriesKcal: caloriesPerServing * servings,
            proteinGrams: proteinPerServing * servings,
            carbsGrams: carbsPerServing * servings,
            fatGrams: fatPerServing * servings
        )
        let mealType = Self.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let entry = MealEntry(
            mealType: mealType,
            source: .recipe,
            portionMultiplier: 1,
            items: [item]
        )
        recipe.cookCount += 1
        recipe.updatedAt = Date()
        return entry
    }

    static func suggestedMealType(forHour hour: Int) -> MealType {
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}
