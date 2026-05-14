import Foundation
import SwiftData

/// Single source of truth for which `@Model` types are part of the on-disk
/// store. The versioned wrapper is what `ModelContainer` and any future
/// `SchemaMigrationPlan` reach for — adding a model means appending it
/// here, never re-listing it at the call site.
enum MealgramSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [
            User.self,
            MealEntry.self,
            FoodItem.self,
            Food.self,
            Recipe.self,
            RecipeIngredient.self,
            Calibration.self,
            Streak.self,
            Achievement.self,
            WeightEntry.self,
            CoachInsightLog.self,
            CoachMemoryNote.self,
            WaterEntry.self,
            CustomGoal.self,
            FavoriteMeal.self,
        ]
    }
}
