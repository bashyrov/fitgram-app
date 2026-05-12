import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class MealRepositoryTests: XCTestCase {
    private var controller: PersistenceController!
    private var repository: MealRepository!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        repository = MealRepository(container: controller.container)
    }

    override func tearDown() async throws {
        repository = nil
        controller = nil
    }

    private func seedMeal(
        kcal: Double = 500,
        portion: Double = 1.0
    ) throws -> MealEntry {
        let meal = MealEntry(
            consumedAt: Date(),
            mealType: .lunch,
            source: .quickDatabase,
            portionMultiplier: portion,
            items: [
                FoodItem(
                    name: "Schabowy",
                    quantityGrams: 200,
                    caloriesKcal: kcal,
                    proteinGrams: 30,
                    carbsGrams: 0,
                    fatGrams: 20
                )
            ]
        )
        let context = ModelContext(controller.container)
        context.insert(meal)
        try context.save()
        return meal
    }

    func testDeleteRemovesMealFromStore() throws {
        let meal = try seedMeal()

        try repository.delete(meal)

        let context = ModelContext(controller.container)
        let count = try context.fetchCount(FetchDescriptor<MealEntry>())
        XCTAssertEqual(count, 0)
    }

    func testDeleteOfMissingMealIsNoOp() throws {
        let ghost = MealEntry(mealType: .snack, source: .manual)
        XCTAssertNoThrow(try repository.delete(ghost))
    }

    func testUpdatePortionPersists() throws {
        let meal = try seedMeal(kcal: 600, portion: 1.0)

        try repository.updatePortion(meal, multiplier: 0.5)

        let context = ModelContext(controller.container)
        let stored = try context.fetch(FetchDescriptor<MealEntry>()).first
        XCTAssertEqual(stored?.portionMultiplier, 0.5)
        XCTAssertEqual(stored?.totalCaloriesKcal, 300)
    }

    func testUpdatePortionClampedAtLowerBound() throws {
        let meal = try seedMeal()

        try repository.updatePortion(meal, multiplier: 0.0)

        let context = ModelContext(controller.container)
        let stored = try context.fetch(FetchDescriptor<MealEntry>()).first
        XCTAssertEqual(stored?.portionMultiplier, 0.05)
    }

    func testUpdatePortionOnMissingMealThrows() throws {
        let ghost = MealEntry(mealType: .snack, source: .manual)
        XCTAssertThrowsError(try repository.updatePortion(ghost, multiplier: 0.5)) { error in
            XCTAssertEqual(error as? MealRepositoryError, .notFound)
        }
    }

    // MARK: - Tags

    func testUpdateTagsPersistsLowerCasedDedupedList() throws {
        let meal = try seedMeal()

        try repository.updateTags(meal, tags: ["Restaurant", "post-workout", "restaurant", "  "])

        let context = ModelContext(controller.container)
        let stored = try context.fetch(FetchDescriptor<MealEntry>()).first
        XCTAssertEqual(stored?.tags, ["restaurant", "post-workout"])
    }

    func testUpdateTagsOnMissingMealThrows() throws {
        let ghost = MealEntry(mealType: .snack, source: .manual)
        XCTAssertThrowsError(try repository.updateTags(ghost, tags: ["x"])) { error in
            XCTAssertEqual(error as? MealRepositoryError, .notFound)
        }
    }
}
