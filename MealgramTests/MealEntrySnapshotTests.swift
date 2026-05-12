import XCTest

@testable import Mealgram

final class MealEntrySnapshotTests: XCTestCase {
    func testCaptureCopiesAllNutritionFields() {
        let item = FoodItem(
            name: "Schabowy",
            quantityGrams: 180,
            caloriesKcal: 420,
            proteinGrams: 32,
            carbsGrams: 18,
            fatGrams: 22,
            fiberGrams: 2,
            confidence: 0.9
        )
        let meal = MealEntry(
            consumedAt: Date(timeIntervalSince1970: 1_715_000_000),
            mealType: .lunch,
            source: .photoScan,
            notes: "Po treningu",
            portionMultiplier: 1.5,
            items: [item]
        )

        let snapshot = MealEntrySnapshot.capture(from: meal)
        XCTAssertEqual(snapshot.mealType, .lunch)
        XCTAssertEqual(snapshot.source, .photoScan)
        XCTAssertEqual(snapshot.notes, "Po treningu")
        XCTAssertEqual(snapshot.portionMultiplier, 1.5)
        XCTAssertEqual(snapshot.items.count, 1)
        XCTAssertEqual(snapshot.items.first?.fiberGrams, 2)
        XCTAssertEqual(snapshot.items.first?.confidence, 0.9)
    }

    func testRestoredEntryPreservesPortionAndItems() {
        let original = MealEntry(
            consumedAt: Date(),
            mealType: .breakfast,
            source: .quickDatabase,
            portionMultiplier: 0.75,
            items: [
                FoodItem(
                    name: "Owsianka",
                    quantityGrams: 200,
                    caloriesKcal: 200,
                    proteinGrams: 6,
                    carbsGrams: 40,
                    fatGrams: 4
                )
            ]
        )
        let snapshot = MealEntrySnapshot.capture(from: original)

        let rebuilt = snapshot.makeEntry()
        XCTAssertEqual(rebuilt.mealType, original.mealType)
        XCTAssertEqual(rebuilt.source, original.source)
        XCTAssertEqual(rebuilt.portionMultiplier, original.portionMultiplier)
        XCTAssertEqual(rebuilt.items.count, original.items.count)
        XCTAssertEqual(rebuilt.totalCaloriesKcal, original.totalCaloriesKcal, accuracy: 0.001)
    }

    func testRestoredEntryHasFreshUUIDs() {
        let meal = MealEntry(
            mealType: .snack,
            source: .manual,
            items: [FoodItem(name: "Banan", quantityGrams: 120, caloriesKcal: 100)]
        )
        let snapshot = MealEntrySnapshot.capture(from: meal)

        let rebuilt = snapshot.makeEntry()
        XCTAssertNotEqual(rebuilt.id, meal.id)
        XCTAssertNotEqual(rebuilt.items.first?.id, meal.items.first?.id)
    }
}
