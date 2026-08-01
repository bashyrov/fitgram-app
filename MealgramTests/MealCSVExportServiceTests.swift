import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class MealCSVExportServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        UserDefaults.standard.set("en", forKey: "app.language")
        Bundle.setLanguage("en")
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
        UserDefaults.standard.removeObject(forKey: "app.language")
    }

    func testEscapeQuotesValuesContainingCommas() {
        XCTAssertEqual(MealCSVExportService.escape("plain"), "plain")
        XCTAssertEqual(MealCSVExportService.escape("with, comma"), "\"with, comma\"")
        XCTAssertEqual(MealCSVExportService.escape("he said \"hi\""), "\"he said \"\"hi\"\"\"")
    }

    func testFormatStripsTrailingZerosForWholeNumbers() {
        XCTAssertEqual(MealCSVExportService.format(100), "100")
        XCTAssertEqual(MealCSVExportService.format(1.5), "1.50")
        XCTAssertEqual(MealCSVExportService.format(0), "0")
    }

    func testEmptyStoreReturnsHeaderOnly() throws {
        let service = MealCSVExportService(container: controller.container)
        let csv = try service.buildCSV()
        XCTAssertEqual(csv.components(separatedBy: "\n").count, 1)
        XCTAssertTrue(csv.hasPrefix("date,time,type,source"))
        XCTAssertTrue(csv.contains(",rating,tags"))
    }

    func testRatingAndTagsAppearInRow() throws {
        let context = ModelContext(controller.container)
        let meal = MealEntry(
            mealType: .lunch,
            source: .quickDatabase,
            items: [FoodItem(name: "X", quantityGrams: 100, caloriesKcal: 100)]
        )
        meal.rating = 4
        meal.tags = ["domowe", "treningowe"]
        context.insert(meal)
        try context.save()

        let csv = try MealCSVExportService(container: controller.container).buildCSV()
        XCTAssertTrue(csv.contains(",4,domowe treningowe"))
    }

    func testOneRowPerFoodItem() throws {
        let context = ModelContext(controller.container)
        let meal = MealEntry(
            consumedAt: ISO8601DateFormatter().date(from: "2026-05-12T13:30:00Z") ?? Date(),
            mealType: .lunch,
            source: .photoScan,
            portionMultiplier: 1.0,
            items: [
                FoodItem(name: "Schabowy", quantityGrams: 180, caloriesKcal: 420, proteinGrams: 32),
                FoodItem(name: "Ziemniaki", quantityGrams: 200, caloriesKcal: 160, proteinGrams: 4),
            ]
        )
        context.insert(meal)
        try context.save()

        let service = MealCSVExportService(container: controller.container)
        let csv = try service.buildCSV()
        let rows = csv.components(separatedBy: "\n")
        // 1 header + 2 items — order within a single meal is determined
        // by SwiftData's @Relationship array, which makes no ordering
        // guarantees, so we assert presence rather than position.
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(csv.contains("Schabowy"))
        XCTAssertTrue(csv.contains("Ziemniaki"))
    }

    func testDateRangeFiltersMealsOutsideWindow() throws {
        let context = ModelContext(controller.container)
        let iso = ISO8601DateFormatter()
        let monthAgo = iso.date(from: "2026-04-10T13:00:00Z") ?? Date()
        let lastWeek = iso.date(from: "2026-05-06T13:00:00Z") ?? Date()
        context.insert(
            MealEntry(
                consumedAt: monthAgo,
                mealType: .lunch,
                source: .manual,
                items: [FoodItem(name: "Stary", quantityGrams: 100, caloriesKcal: 100)]
            )
        )
        context.insert(
            MealEntry(
                consumedAt: lastWeek,
                mealType: .lunch,
                source: .manual,
                items: [FoodItem(name: "Świeży", quantityGrams: 100, caloriesKcal: 100)]
            )
        )
        try context.save()

        let service = MealCSVExportService(container: controller.container)
        let from = iso.date(from: "2026-05-01T00:00:00Z")
        let to = iso.date(from: "2026-05-12T23:59:59Z")
        let csv = try service.buildCSV(from: from, to: to)
        XCTAssertFalse(csv.contains("Stary"), "Out-of-range meal should be excluded")
        XCTAssertTrue(csv.contains("Świeży"), "In-range meal should be included")
    }

    func testPortionMultiplierAppliedToMacros() throws {
        let context = ModelContext(controller.container)
        let meal = MealEntry(
            mealType: .dinner,
            source: .quickDatabase,
            portionMultiplier: 0.5,
            items: [FoodItem(name: "x", quantityGrams: 100, caloriesKcal: 200, proteinGrams: 30)]
        )
        context.insert(meal)
        try context.save()

        let csv = try MealCSVExportService(container: controller.container).buildCSV()
        // Portion 0.5 × 200 kcal = 100 kcal
        XCTAssertTrue(csv.contains(",100,"))
    }
}
