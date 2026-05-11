import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class PersistenceTests: XCTestCase {
    private var controller: PersistenceController!
    private var context: ModelContext!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        context = ModelContext(controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        context = nil
    }

    func testInsertAndFetchMealEntryRoundTrip() throws {
        let item = FoodItem(
            name: "Kotlet schabowy",
            quantityGrams: 180,
            caloriesKcal: 420,
            proteinGrams: 32,
            carbsGrams: 18,
            fatGrams: 22
        )
        let entry = MealEntry(
            mealType: .lunch,
            source: .photoScan,
            portionMultiplier: 1.0,
            items: [item]
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<MealEntry>())
        XCTAssertEqual(fetched.count, 1)
        let restored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(restored.items.count, 1)
        XCTAssertEqual(restored.mealType, .lunch)
        XCTAssertEqual(restored.totalCaloriesKcal, 420, accuracy: 0.0001)
    }

    func testCascadeDeleteRemovesFoodItems() throws {
        let entry = MealEntry(
            mealType: .dinner,
            source: .manual,
            items: [
                FoodItem(name: "A", quantityGrams: 100, caloriesKcal: 100),
                FoodItem(name: "B", quantityGrams: 50, caloriesKcal: 50),
            ]
        )
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let remainingItems = try context.fetch(FetchDescriptor<FoodItem>())
        XCTAssertTrue(remainingItems.isEmpty, "FoodItem children should cascade with their meal")
    }

    func testFoodItemFromFoodCatalogScalesNutrition() {
        let food = Food(
            name: "Kurczak grillowany",
            category: .meat,
            caloriesKcalPer100g: 165,
            proteinGramsPer100g: 31,
            carbsGramsPer100g: 0,
            fatGramsPer100g: 3.6
        )
        let item = FoodItem.from(food: food, quantityGrams: 200)
        XCTAssertEqual(item.caloriesKcal, 330, accuracy: 0.001)
        XCTAssertEqual(item.proteinGrams, 62, accuracy: 0.001)
        XCTAssertEqual(item.carbsGrams, 0, accuracy: 0.001)
        XCTAssertEqual(item.fatGrams, 7.2, accuracy: 0.001)
        XCTAssertEqual(item.catalogFoodID, food.id)
    }

    func testWipeAllDataDropsEveryModel() throws {
        let user = User(remoteID: "u-1")
        let entry = MealEntry(mealType: .breakfast, source: .quickDatabase)
        let recipe = Recipe(title: "Naleśniki")
        let achievement = Achievement(userRemoteID: "u-1", kind: "scan.first", title: "Pierwsze danie", details: "")
        context.insert(user)
        context.insert(entry)
        context.insert(recipe)
        context.insert(achievement)
        try context.save()

        try controller.wipeAllData()

        let users = try context.fetch(FetchDescriptor<User>())
        let entries = try context.fetch(FetchDescriptor<MealEntry>())
        let recipes = try context.fetch(FetchDescriptor<Recipe>())
        let achievements = try context.fetch(FetchDescriptor<Achievement>())
        XCTAssertTrue(users.isEmpty)
        XCTAssertTrue(entries.isEmpty)
        XCTAssertTrue(recipes.isEmpty)
        XCTAssertTrue(achievements.isEmpty)
    }

    func testTotalsHonorPortionMultiplier() throws {
        let entry = MealEntry(
            mealType: .snack,
            source: .manual,
            portionMultiplier: 1.5,
            items: [
                FoodItem(
                    name: "Banan", quantityGrams: 120, caloriesKcal: 100, proteinGrams: 1, carbsGrams: 25, fatGrams: 0)
            ]
        )
        context.insert(entry)
        try context.save()

        XCTAssertEqual(entry.totalCaloriesKcal, 150, accuracy: 0.001)
        XCTAssertEqual(entry.totalCarbsGrams, 37.5, accuracy: 0.001)
    }
}
