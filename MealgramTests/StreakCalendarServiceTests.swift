import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class StreakCalendarServiceTests: XCTestCase {
    private var controller: PersistenceController!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
    }

    override func tearDown() async throws {
        controller = nil
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("bad iso") }
        return date
    }

    private static func utcMondayCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    func testSnapshotPadsLeadingCellsToMonday() {
        // 2026-05-01 is a Friday → 4 leading placeholder cells.
        let may = Self.date("2026-05-15T12:00:00Z")
        let service = StreakCalendarService(
            container: controller.container,
            calendar: Self.utcMondayCalendar()
        )
        let snapshot = service.snapshot(month: may)
        guard let firstWeek = snapshot.weeks.first else {
            return XCTFail("no weeks")
        }
        let placeholders = firstWeek.days.prefix(while: \.isPlaceholder).count
        XCTAssertEqual(placeholders, 4)
        let firstReal = firstWeek.days.first(where: { !$0.isPlaceholder })
        XCTAssertEqual(firstReal?.dayOfMonth, 1)
    }

    func testLoggedDayFlagged() throws {
        let context = ModelContext(controller.container)
        let day = Self.date("2026-05-12T13:00:00Z")
        context.insert(
            MealEntry(
                consumedAt: day, mealType: .lunch, source: .quickDatabase,
                items: [FoodItem(name: "x", quantityGrams: 100, caloriesKcal: 200)]
            )
        )
        try context.save()

        let service = StreakCalendarService(
            container: controller.container,
            calendar: Self.utcMondayCalendar()
        )
        let snapshot = service.snapshot(month: day)
        let day12 = snapshot.weeks.flatMap(\.days).first { $0.dayOfMonth == 12 }
        XCTAssertEqual(day12?.isLogged, true)

        let day13 = snapshot.weeks.flatMap(\.days).first { $0.dayOfMonth == 13 }
        XCTAssertEqual(day13?.isLogged, false)
    }

    func testMonthWithoutEntriesHasNoLoggedDays() {
        let service = StreakCalendarService(
            container: controller.container,
            calendar: Self.utcMondayCalendar()
        )
        let snapshot = service.snapshot(month: Self.date("2026-03-01T12:00:00Z"))
        let logged = snapshot.weeks.flatMap(\.days).filter { $0.isLogged }
        XCTAssertTrue(logged.isEmpty)
    }

    func testTotalDayCountMatchesMonthLength() {
        let service = StreakCalendarService(
            container: controller.container,
            calendar: Self.utcMondayCalendar()
        )
        let snapshot = service.snapshot(month: Self.date("2026-05-15T12:00:00Z"))
        let realDays = snapshot.weeks.flatMap(\.days).filter { !$0.isPlaceholder }
        XCTAssertEqual(realDays.count, 31)
    }
}
