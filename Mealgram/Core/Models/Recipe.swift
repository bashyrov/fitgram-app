import Foundation
import SwiftData

/// A user's saved recipe — typed in, pasted from a URL, or photo-OCR'd.
/// `modifications` is a free-text note the user attached on a particular
/// cook (the AI recalculation engine in Phase 3 will read & write here).
@Model
final class Recipe {
    var id: UUID
    var remoteID: String?

    var title: String
    var summary: String?
    var sourceURLString: String?
    var imageFilename: String?

    var servings: Int
    var prepMinutes: Int?
    var cookMinutes: Int?

    /// Markdown-ish step list, one entry per step.
    var instructions: [String]
    /// Free-text adjustments ("mniej masła, podwójna porcja kurczaka"), one
    /// per cook session. Phase 3 fills these into a separate modification
    /// engine — for now this is just a string list.
    var modifications: [String]

    var caloriesPerServing: Double?
    var proteinPerServing: Double?
    var carbsPerServing: Double?
    var fatPerServing: Double?

    var cookCount: Int
    var rating: Double?
    /// User favorited the recipe. Defaults false so SwiftData lightweight
    /// migration keeps existing rows valid.
    var isFavorite: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient]

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        summary: String? = nil,
        sourceURL: URL? = nil,
        servings: Int = 2,
        prepMinutes: Int? = nil,
        cookMinutes: Int? = nil,
        instructions: [String] = [],
        ingredients: [RecipeIngredient] = []
    ) {
        let now = Date()
        self.id = id
        self.title = title
        self.summary = summary
        self.sourceURLString = sourceURL?.absoluteString
        self.servings = servings
        self.prepMinutes = prepMinutes
        self.cookMinutes = cookMinutes
        self.instructions = instructions
        self.modifications = []
        self.cookCount = 0
        self.ingredients = ingredients
        self.createdAt = now
        self.updatedAt = now
    }
}

extension Recipe {
    var sourceURL: URL? {
        get { sourceURLString.flatMap(URL.init(string:)) }
        set { sourceURLString = newValue?.absoluteString }
    }
}
