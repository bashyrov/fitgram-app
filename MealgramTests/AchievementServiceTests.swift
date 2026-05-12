import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class AchievementServiceTests: XCTestCase {
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

    func testEvaluatePersistsUnlockedAchievementsAndIsIdempotent() throws {
        let meal = MealEntry(
            consumedAt: Date(),
            mealType: .lunch,
            source: .photoScan,
            items: [FoodItem(name: "Test", quantityGrams: 100, caloriesKcal: 100)]
        )
        context.insert(meal)
        try context.save()

        let service = AchievementService(container: controller.container)
        let first = try service.evaluate(forUser: "u-1")
        let ids = Set(first.map(\.id))
        XCTAssertTrue(ids.contains("meal.first"))
        XCTAssertTrue(ids.contains("scan.first"))

        let stored = try service.earned(forUser: "u-1")
        XCTAssertEqual(stored.count, first.count)

        let second = try service.evaluate(forUser: "u-1")
        XCTAssertTrue(second.isEmpty, "Second evaluate should grant nothing new")
    }

    func testEarnedReturnsNewestFirst() throws {
        let user = "u-2"
        let now = Date()
        let older = Achievement(
            userRemoteID: user,
            kind: "meal.first",
            title: "x",
            details: "x",
            earnedAt: now.addingTimeInterval(-3600)
        )
        let newer = Achievement(
            userRemoteID: user,
            kind: "scan.first",
            title: "y",
            details: "y",
            earnedAt: now
        )
        context.insert(older)
        context.insert(newer)
        try context.save()

        let service = AchievementService(container: controller.container)
        let result = try service.earned(forUser: user)
        XCTAssertEqual(result.first?.kind, "scan.first")
        XCTAssertEqual(result.last?.kind, "meal.first")
    }

    func testEvaluateRespectsAlreadyEarnedFromPersistence() throws {
        context.insert(
            Achievement(
                userRemoteID: "u-3",
                kind: "meal.first",
                title: "Pierwsze danie",
                details: ""
            ))
        let meal = MealEntry(
            consumedAt: Date(),
            mealType: .lunch,
            source: .barcode,
            items: [FoodItem(name: "Test", quantityGrams: 100, caloriesKcal: 100)]
        )
        context.insert(meal)
        try context.save()

        let service = AchievementService(container: controller.container)
        let unlocks = try service.evaluate(forUser: "u-3")
        let ids = Set(unlocks.map(\.id))
        XCTAssertFalse(ids.contains("meal.first"), "meal.first was already earned")
        XCTAssertTrue(ids.contains("barcode.first"))
    }
}
