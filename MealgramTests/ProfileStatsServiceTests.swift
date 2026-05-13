import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class ProfileStatsServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    func testEmptyStoreReturnsZerosAndNilMemberSince() {
        let service = ProfileStatsService(container: controller.container)
        let summary = service.summary(for: "u-x")
        XCTAssertEqual(summary.totalMeals, 0)
        XCTAssertEqual(summary.totalRecipes, 0)
        XCTAssertEqual(summary.totalWeightEntries, 0)
        XCTAssertEqual(summary.totalAchievements, 0)
        XCTAssertNil(summary.memberSince)
    }

    func testCountsAllRowsForUser() throws {
        let context = ModelContext(controller.container)
        let user = User(remoteID: "u-x", displayName: "Ola", providerKind: .apple)
        context.insert(user)
        context.insert(
            MealEntry(
                mealType: .lunch, source: .quickDatabase,
                items: [FoodItem(name: "x", quantityGrams: 100, caloriesKcal: 200)]
            )
        )
        context.insert(
            MealEntry(
                mealType: .dinner, source: .photoScan,
                items: [FoodItem(name: "y", quantityGrams: 100, caloriesKcal: 300)]
            )
        )
        context.insert(Recipe(title: "Schabowy"))
        context.insert(WeightEntry(userRemoteID: "u-x", recordedAt: Date(), weightKg: 72))
        context.insert(
            Achievement(
                userRemoteID: "u-x", kind: "meal.first",
                title: "Pierwsze danie", details: "",
                earnedAt: Date()
            )
        )
        try context.save()

        let summary = ProfileStatsService(container: controller.container).summary(for: "u-x")
        XCTAssertEqual(summary.totalMeals, 2)
        XCTAssertEqual(summary.totalRecipes, 1)
        XCTAssertEqual(summary.totalWeightEntries, 1)
        XCTAssertEqual(summary.totalAchievements, 1)
        XCTAssertEqual(summary.totalCaloriesKcal, 500, "Should sum 200 + 300 across the two meals")
        XCTAssertNotNil(summary.memberSince)
    }

    func testTotalRecipeCooksSumsAcrossRecipes() throws {
        let context = ModelContext(controller.container)
        context.insert(User(remoteID: "u-x", providerKind: .apple))
        let r1 = Recipe(title: "Schabowy")
        r1.cookCount = 5
        let r2 = Recipe(title: "Pierogi")
        r2.cookCount = 3
        let r3 = Recipe(title: "Nieugotowany")
        context.insert(r1)
        context.insert(r2)
        context.insert(r3)
        try context.save()

        let summary = ProfileStatsService(container: controller.container).summary(for: "u-x")
        XCTAssertEqual(summary.totalRecipeCooks, 8)
    }

    func testWeightAndAchievementsSegregatePerUser() throws {
        let context = ModelContext(controller.container)
        context.insert(User(remoteID: "u-a", providerKind: .apple))
        context.insert(User(remoteID: "u-b", providerKind: .apple))
        context.insert(WeightEntry(userRemoteID: "u-a", recordedAt: Date(), weightKg: 70))
        context.insert(WeightEntry(userRemoteID: "u-b", recordedAt: Date(), weightKg: 80))
        context.insert(WeightEntry(userRemoteID: "u-b", recordedAt: Date(), weightKg: 81))
        try context.save()

        let service = ProfileStatsService(container: controller.container)
        XCTAssertEqual(service.summary(for: "u-a").totalWeightEntries, 1)
        XCTAssertEqual(service.summary(for: "u-b").totalWeightEntries, 2)
    }
}
