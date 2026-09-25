import Foundation
import SwiftData

/// One eating event. Photo scan, voice input, recipe cook, quick-database
/// pick — they all land here. The line items live in `FoodItem` so a single
/// meal can include "kotlet schabowy + ziemniaki + surówka" as three
/// separately editable entries while still summing to one calorie total.
@Model
final class MealEntry {
    var id: UUID = UUID()
    var remoteID: String?

    var consumedAt: Date = Date()
    var mealTypeRaw: String = ""
    var sourceRaw: String = ""
    var notes: String?
    var photoFilename: String?
    /// Free-form tags the user attaches (post-workout, restaurant,
    /// homemade, ...). Stored as a String array — SwiftData handles
    /// the encoding. Empty default keeps existing rows valid after the
    /// lightweight migration.
    var tags: [String] = []
    /// User-applied portion multiplier (1.0 = original detection). Stored
    /// separately so we can show the AI's raw output vs. the user's edit.
    var portionMultiplier: Double = 0
    /// Optional 1-5 rating for how much the user enjoyed the meal. Nil
    /// until they actively rate. Default-nil keeps existing rows valid
    /// post lightweight migration.
    var rating: Int?

    @Relationship(deleteRule: .cascade, inverse: \FoodItem.meal)
    var items: [FoodItem] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    init(
        id: UUID = UUID(),
        consumedAt: Date = Date(),
        mealType: MealType,
        source: MealSource,
        notes: String? = nil,
        photoFilename: String? = nil,
        portionMultiplier: Double = 1.0,
        tags: [String] = [],
        items: [FoodItem] = []
    ) {
        let now = Date()
        self.id = id
        self.consumedAt = consumedAt
        self.mealTypeRaw = mealType.rawValue
        self.sourceRaw = source.rawValue
        self.notes = notes
        self.photoFilename = photoFilename
        self.portionMultiplier = portionMultiplier
        self.tags = tags
        self.items = items
        self.createdAt = now
        self.updatedAt = now
    }
}

extension MealEntry {
    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var source: MealSource {
        get { MealSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var totalCaloriesKcal: Double {
        items.reduce(0) { $0 + $1.caloriesKcal } * portionMultiplier
    }

    var totalProteinGrams: Double {
        items.reduce(0) { $0 + $1.proteinGrams } * portionMultiplier
    }

    var totalCarbsGrams: Double {
        items.reduce(0) { $0 + $1.carbsGrams } * portionMultiplier
    }

    var totalFatGrams: Double {
        items.reduce(0) { $0 + $1.fatGrams } * portionMultiplier
    }
}
