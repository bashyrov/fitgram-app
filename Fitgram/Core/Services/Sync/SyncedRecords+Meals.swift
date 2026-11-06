import Foundation
import SwiftData

// Meals, recipes and the user's own foods.

struct MealRecord: SyncedRecord {
    struct Item: Codable {
        var id: UUID
        var name: String
        var quantityGrams: Double
        var caloriesKcal: Double
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var fiberGrams: Double?
        var catalogFoodID: UUID?
        var confidence: Double?
    }

    static let kind = "meal"

    var consumedAt: Date
    var mealType: String
    var source: String
    var notes: String?
    var photoFilename: String?
    var tags: [String]
    var portionMultiplier: Double
    var rating: Int?
    var createdAt: Date
    var items: [Item]

    static func owned(by owner: String, in context: ModelContext) throws -> [MealEntry] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: MealEntry) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> MealEntry? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> MealEntry {
        let meal = MealEntry(id: UUID(uuidString: id) ?? UUID(), mealType: .snack, source: .manual)
        meal.userRemoteID = owner
        context.insert(meal)
        return meal
    }

    init(_ model: MealEntry) {
        consumedAt = model.consumedAt
        mealType = model.mealTypeRaw
        source = model.sourceRaw
        notes = model.notes
        photoFilename = model.photoFilename
        tags = model.tags
        portionMultiplier = model.portionMultiplier
        rating = model.rating
        createdAt = model.createdAt
        items = model.items.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            Item(
                id: $0.id, name: $0.name, quantityGrams: $0.quantityGrams, caloriesKcal: $0.caloriesKcal,
                proteinGrams: $0.proteinGrams, carbsGrams: $0.carbsGrams, fatGrams: $0.fatGrams,
                fiberGrams: $0.fiberGrams, catalogFoodID: $0.catalogFoodID, confidence: $0.confidence)
        }
    }

    func apply(to model: MealEntry, in context: ModelContext) {
        model.consumedAt = consumedAt
        model.mealTypeRaw = mealType
        model.sourceRaw = source
        model.notes = notes
        model.photoFilename = photoFilename
        model.tags = tags
        model.portionMultiplier = portionMultiplier
        model.rating = rating
        model.createdAt = createdAt
        model.updatedAt = Date()
        model.items.forEach(context.delete)
        model.items = items.map {
            FoodItem(
                id: $0.id, name: $0.name, quantityGrams: $0.quantityGrams, caloriesKcal: $0.caloriesKcal,
                proteinGrams: $0.proteinGrams, carbsGrams: $0.carbsGrams, fatGrams: $0.fatGrams,
                fiberGrams: $0.fiberGrams, catalogFoodID: $0.catalogFoodID, confidence: $0.confidence)
        }
    }
}

struct RecipeRecord: SyncedRecord {
    struct Ingredient: Codable {
        var id: UUID
        var name: String
        var quantityText: String?
        var quantityGrams: Double?
        var note: String?
        var catalogFoodID: UUID?
    }

    static let kind = "recipe"

    var title: String
    var summary: String?
    var sourceURLString: String?
    var servings: Int
    var prepMinutes: Int?
    var cookMinutes: Int?
    var instructions: [String]
    var modifications: [String]
    var caloriesPerServing: Double?
    var proteinPerServing: Double?
    var carbsPerServing: Double?
    var fatPerServing: Double?
    var cookCount: Int
    var rating: Double?
    var isFavorite: Bool
    var createdAt: Date
    var ingredients: [Ingredient]

    static func owned(by owner: String, in context: ModelContext) throws -> [Recipe] {
        try fetch(#Predicate { $0.userRemoteID == owner }, in: context)
    }

    static func recordID(of model: Recipe) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Recipe? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.userRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Recipe {
        let recipe = Recipe(id: UUID(uuidString: id) ?? UUID(), title: "")
        recipe.userRemoteID = owner
        context.insert(recipe)
        return recipe
    }

    init(_ model: Recipe) {
        title = model.title
        summary = model.summary
        sourceURLString = model.sourceURLString
        servings = model.servings
        prepMinutes = model.prepMinutes
        cookMinutes = model.cookMinutes
        instructions = model.instructions
        modifications = model.modifications
        caloriesPerServing = model.caloriesPerServing
        proteinPerServing = model.proteinPerServing
        carbsPerServing = model.carbsPerServing
        fatPerServing = model.fatPerServing
        cookCount = model.cookCount
        rating = model.rating
        isFavorite = model.isFavorite
        createdAt = model.createdAt
        ingredients = model.ingredients.sorted { $0.id.uuidString < $1.id.uuidString }.map {
            Ingredient(
                id: $0.id, name: $0.name, quantityText: $0.quantityText, quantityGrams: $0.quantityGrams,
                note: $0.note, catalogFoodID: $0.catalogFoodID)
        }
    }

    func apply(to model: Recipe, in context: ModelContext) {
        model.title = title
        model.summary = summary
        model.sourceURLString = sourceURLString
        model.servings = servings
        model.prepMinutes = prepMinutes
        model.cookMinutes = cookMinutes
        model.instructions = instructions
        model.modifications = modifications
        model.caloriesPerServing = caloriesPerServing
        model.proteinPerServing = proteinPerServing
        model.carbsPerServing = carbsPerServing
        model.fatPerServing = fatPerServing
        model.cookCount = cookCount
        model.rating = rating
        model.isFavorite = isFavorite
        model.createdAt = createdAt
        model.updatedAt = Date()
        model.ingredients.forEach(context.delete)
        model.ingredients = ingredients.map {
            RecipeIngredient(
                id: $0.id, name: $0.name, quantityText: $0.quantityText, quantityGrams: $0.quantityGrams,
                note: $0.note, catalogFoodID: $0.catalogFoodID)
        }
    }
}

/// "My kitchen" foods the account created in Quick DB.
struct CustomFoodRecord: SyncedRecord {
    static let kind = "food"

    var name: String
    var localizationsJSON: String?
    var brand: String?
    var restaurantName: String?
    var category: String
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double
    var fiberGramsPer100g: Double?
    var defaultPortionGrams: Double?
    var barcode: String?
    var imageURLString: String?
    var createdAt: Date

    static func owned(by owner: String, in context: ModelContext) throws -> [Food] {
        try fetch(#Predicate { $0.ownerRemoteID == owner }, in: context)
    }

    static func recordID(of model: Food) -> String { model.id.uuidString }

    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Food? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return try fetch(#Predicate { $0.id == uuid && $0.ownerRemoteID == owner }, in: context).first
    }

    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Food {
        let food = Food(id: UUID(uuidString: id) ?? UUID(), name: "", caloriesKcalPer100g: 0)
        food.ownerRemoteID = owner
        context.insert(food)
        return food
    }

    init(_ model: Food) {
        name = model.name
        localizationsJSON = model.localizationsJSON
        brand = model.brand
        restaurantName = model.restaurantName
        category = model.categoryRaw
        caloriesKcalPer100g = model.caloriesKcalPer100g
        proteinGramsPer100g = model.proteinGramsPer100g
        carbsGramsPer100g = model.carbsGramsPer100g
        fatGramsPer100g = model.fatGramsPer100g
        fiberGramsPer100g = model.fiberGramsPer100g
        defaultPortionGrams = model.defaultPortionGrams
        barcode = model.barcode
        imageURLString = model.imageURLString
        createdAt = model.createdAt
    }

    func apply(to model: Food, in context: ModelContext) {
        model.name = name
        model.localizationsJSON = localizationsJSON
        model.brand = brand
        model.restaurantName = restaurantName
        model.categoryRaw = category
        model.caloriesKcalPer100g = caloriesKcalPer100g
        model.proteinGramsPer100g = proteinGramsPer100g
        model.carbsGramsPer100g = carbsGramsPer100g
        model.fatGramsPer100g = fatGramsPer100g
        model.fiberGramsPer100g = fiberGramsPer100g
        model.defaultPortionGrams = defaultPortionGrams
        model.barcode = barcode
        model.imageURLString = imageURLString
        model.createdAt = createdAt
        model.verified = false
    }
}
