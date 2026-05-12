import XCTest

@testable import Mealgram

final class CoachDismissalStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "CoachDismissalStoreTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad iso") }
        return date
    }

    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    func testDismissAndCheckRoundTrip() {
        let now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachDismissalStore(
            defaults: defaults,
            calendar: Self.utcCalendar(),
            now: { now }
        )
        XCTAssertFalse(store.isDismissed(headline: "Brawo!"))
        store.dismiss(headline: "Brawo!")
        XCTAssertTrue(store.isDismissed(headline: "Brawo!"))
    }

    func testMultipleHeadlinesAccumulate() {
        let now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachDismissalStore(
            defaults: defaults, calendar: Self.utcCalendar(), now: { now }
        )
        store.dismiss(headline: "A")
        store.dismiss(headline: "B")
        XCTAssertEqual(store.todaysDismissed(), ["A", "B"])
    }

    func testDifferentDaysDontCarryOver() {
        var now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachDismissalStore(
            defaults: defaults, calendar: Self.utcCalendar(), now: { now }
        )
        store.dismiss(headline: "Brawo!")
        // Move clock forward by a day.
        now = Self.date("2026-05-13T12:00:00Z")
        XCTAssertFalse(store.isDismissed(headline: "Brawo!"))
        XCTAssertEqual(store.todaysDismissed(), [])
    }

    func testClearTodayRemovesAllForToday() {
        let now = Self.date("2026-05-12T12:00:00Z")
        let store = CoachDismissalStore(
            defaults: defaults, calendar: Self.utcCalendar(), now: { now }
        )
        store.dismiss(headline: "A")
        store.dismiss(headline: "B")
        store.clearToday()
        XCTAssertTrue(store.todaysDismissed().isEmpty)
    }
}
