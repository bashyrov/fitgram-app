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

    // MARK: - Duplicate

    func testDuplicateProducesFreshEntryWithCopiedItems() throws {
        let meal = try seedMeal(kcal: 420, portion: 1.25)
        let original = try ModelContext(controller.container)
            .fetch(FetchDescriptor<MealEntry>()).first
        try repository.updateTags(meal, tags: ["restaurant"])

        let copy = try repository.duplicate(meal)

        let all = try ModelContext(controller.container)
            .fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(all.count, 2)
        XCTAssertNotEqual(copy.id, original?.id)
        XCTAssertEqual(copy.portionMultiplier, 1.25)
        XCTAssertEqual(copy.items.count, 1)
        XCTAssertNotEqual(copy.items.first?.id, original?.items.first?.id)
        XCTAssertEqual(copy.tags, ["restaurant"])
        XCTAssertNil(copy.photoFilename)
    }

    func testDuplicateUsesProvidedDate() throws {
        let meal = try seedMeal()
        let target = Date(timeIntervalSince1970: 1_700_000_000)
        let copy = try repository.duplicate(meal, at: target)
        XCTAssertEqual(copy.consumedAt, target)
    }

    func testUpdateTagsOnMissingMealThrows() throws {
        let ghost = MealEntry(mealType: .snack, source: .manual)
        XCTAssertThrowsError(try repository.updateTags(ghost, tags: ["x"])) { error in
            XCTAssertEqual(error as? MealRepositoryError, .notFound)
        }
    }

    // MARK: - Notes

    func testUpdateNotesPersistsTrimmedText() throws {
        let meal = try seedMeal()
        try repository.updateNotes(meal, notes: "   Po treningu, dużo wody.  ")
        let stored = try ModelContext(controller.container)
            .fetch(FetchDescriptor<MealEntry>()).first
        XCTAssertEqual(stored?.notes, "Po treningu, dużo wody.")
    }

    // MARK: - Photo orphan check

    func testPhotoIsOrphanedTrueWhenNoMealReferencesFilename() {
        XCTAssertTrue(repository.photoIsOrphaned(filename: "ghost.jpg"))
    }

    func testPhotoIsOrphanedFalseWhenAMealHasIt() throws {
        let meal = MealEntry(
            consumedAt: Date(),
            mealType: .lunch,
            source: .photoScan,
            photoFilename: "owned.jpg",
            items: [FoodItem(name: "x", quantityGrams: 100, caloriesKcal: 100)]
        )
        let context = ModelContext(controller.container)
        context.insert(meal)
        try context.save()
        XCTAssertFalse(repository.photoIsOrphaned(filename: "owned.jpg"))
    }

    func testUpdateNotesStoresNilForEmptyWhitespace() throws {
        let meal = try seedMeal()
        try repository.updateNotes(meal, notes: "first pass")
        try repository.updateNotes(meal, notes: "    \n  ")
        let stored = try ModelContext(controller.container)
            .fetch(FetchDescriptor<MealEntry>()).first
        XCTAssertNil(stored?.notes)
    }
}
