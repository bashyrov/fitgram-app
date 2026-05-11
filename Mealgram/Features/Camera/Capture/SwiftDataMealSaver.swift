import Foundation
import OSLog
import SwiftData

/// Real `MealSaving` implementation — opens a `ModelContext` on the shared
/// container and persists the entry. Wrapped behind the protocol so tests
/// don't need SwiftData.
struct SwiftDataMealSaver: MealSaving {
    let container: ModelContainer

    func save(meal: MealEntry) throws {
        let context = ModelContext(container)
        context.insert(meal)
        try context.save()
        Logger.persistence.notice("Saved meal entry id=\(meal.id, privacy: .public)")
    }
}
