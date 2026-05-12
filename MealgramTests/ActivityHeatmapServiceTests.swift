import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class ActivityHeatmapServiceTests: XCTestCase {
    private var controller: PersistenceController!

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    func testSnapshotProducesNinetyContiguousCells() {
        let now = Date(timeIntervalSince1970: 1_715_500_000)
        let service = ActivityHeatmapService(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )

        let snapshot = service.snapshot(days: 90)
        XCTAssertEqual(snapshot.cells.count, 90)
        let calendar = Self.utcCalendar()
        let firstDate = snapshot.cells.first?.date ?? .distantPast
        let lastDate = snapshot.cells.last?.date ?? .distantPast
        let dayDelta = calendar.dateComponents([.day], from: firstDate, to: lastDate).day
        XCTAssertEqual(dayDelta, 89)
    }

    func testCellsWithoutMealsHaveZeroKcal() {
        let now = Date(timeIntervalSince1970: 1_715_500_000)
        let service = ActivityHeatmapService(
            container: controller.container,
            calendar: Self.utcCalendar(),
            now: { now }
        )

        let snapshot = service.snapshot(days: 30)
        XCTAssertEqual(snapshot.cells.filter { $0.totalKcal == 0 }.count, 30)
    }

    func testMealCaloriesBucketedToCorrectDay() throws {
        let calendar = Self.utcCalendar()
        let now = Date(timeIntervalSince1970: 1_715_500_000)  // 2024-05-12
        guard let twoDaysBack = calendar.date(byAdding: .day, value: -2, to: now) else {
            return XCTFail("calendar math")
        }
        let context = ModelContext(controller.container)
        let meal = MealEntry(
            consumedAt: twoDaysBack,
            mealType: .lunch,
            source: .quickDatabase,
            items: [
                FoodItem(
                    name: "Test",
                    quantityGrams: 100,
                    caloriesKcal: 500,
                    proteinGrams: 0, carbsGrams: 0, fatGrams: 0
                )
            ]
        )
        context.insert(meal)
        try context.save()

        let service = ActivityHeatmapService(
            container: controller.container,
            calendar: calendar,
            now: { now }
        )
        let snapshot = service.snapshot(days: 10)
        let nonZero = snapshot.cells.filter { $0.totalKcal > 0 }
        XCTAssertEqual(nonZero.count, 1)
        XCTAssertEqual(nonZero.first?.totalKcal, 500)
        XCTAssertEqual(nonZero.first?.intensity, 1)
    }

    func testIntensityTiers() {
        XCTAssertEqual(ActivityHeatmap.Cell(date: Date(), totalKcal: 0).intensity, 0)
        XCTAssertEqual(ActivityHeatmap.Cell(date: Date(), totalKcal: 400).intensity, 1)
        XCTAssertEqual(ActivityHeatmap.Cell(date: Date(), totalKcal: 1200).intensity, 2)
        XCTAssertEqual(ActivityHeatmap.Cell(date: Date(), totalKcal: 2500).intensity, 3)
    }
}
