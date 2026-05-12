import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class MealSearchServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    private func seed(_ items: [(name: String, daysAgo: Int)]) throws {
        let context = ModelContext(controller.container)
        for (name, daysAgo) in items {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
            context.insert(
                MealEntry(
                    consumedAt: date,
                    mealType: .lunch,
                    source: .quickDatabase,
                    items: [FoodItem(name: name, quantityGrams: 200, caloriesKcal: 300)]
                )
            )
        }
        try context.save()
    }

    func testEmptyQueryReturnsEmpty() throws {
        try seed([("Schabowy", 0)])
        let results = try MealSearchService(container: controller.container).search(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testCaseInsensitiveSubstringMatch() throws {
        try seed([
            ("Schabowy z kotleta", 1),
            ("Owsianka", 2),
            ("Surówka z kapusty", 3),
        ])
        let service = MealSearchService(container: controller.container)
        let upper = try service.search(query: "SCHAB")
        XCTAssertEqual(upper.count, 1)
        XCTAssertEqual(upper.first?.items.first?.name, "Schabowy z kotleta")
    }

    func testResultsSortedNewestFirst() throws {
        try seed([
            ("Pierogi", 5),
            ("Pierogi", 1),
            ("Pierogi", 3),
        ])
        let results = try MealSearchService(container: controller.container).search(query: "pierogi")
        XCTAssertEqual(results.count, 3)
        // Most recent first → consumedAt desc.
        XCTAssertTrue(results[0].consumedAt > results[1].consumedAt)
        XCTAssertTrue(results[1].consumedAt > results[2].consumedAt)
    }

    func testLimitRespected() throws {
        try seed(Array(repeating: ("Owsianka", 1), count: 8))
        let service = MealSearchService(container: controller.container)
        let three = try service.search(query: "owsianka", limit: 3)
        XCTAssertEqual(three.count, 3)
    }

    func testNoMatchesReturnsEmpty() throws {
        try seed([("Schabowy", 1)])
        let results = try MealSearchService(container: controller.container).search(query: "kasza")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchMatchesByTag() throws {
        let context = ModelContext(controller.container)
        let meal = MealEntry(
            mealType: .lunch, source: .quickDatabase,
            tags: ["restaurant", "weekday"],
            items: [FoodItem(name: "Burger", quantityGrams: 250, caloriesKcal: 700)]
        )
        context.insert(meal)
        try context.save()

        let service = MealSearchService(container: controller.container)
        let restaurant = try service.search(query: "restaurant")
        XCTAssertEqual(restaurant.count, 1)
        let week = try service.search(query: "weekday")
        XCTAssertEqual(week.count, 1)
    }
}
