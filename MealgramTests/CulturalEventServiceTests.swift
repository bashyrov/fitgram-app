import XCTest

@testable import Mealgram

final class CulturalEventServiceTests: XCTestCase {
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad iso: \(iso)") }
        return date
    }

    func testEasterAlgorithmMatchesKnownYears() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        XCTAssertEqual(service.easterSunday(year: 2026), date("2026-04-05T00:00:00Z"))
        XCTAssertEqual(service.easterSunday(year: 2027), date("2027-03-28T00:00:00Z"))
        XCTAssertEqual(service.easterSunday(year: 2028), date("2028-04-16T00:00:00Z"))
        XCTAssertEqual(service.easterSunday(year: 2024), date("2024-03-31T00:00:00Z"))
    }

    func testTlustyCzwartekIs52DaysBeforeEaster() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        // 2026 Easter = Apr 5, Tłusty Czwartek = Feb 12. Test 8 days before.
        let upcoming = service.upcoming(from: date("2026-02-04T08:00:00Z"), lookahead: 14)
        XCTAssertEqual(upcoming?.event.id, "tlustyczwartek")
        XCTAssertEqual(upcoming?.daysAway, 8)
    }

    func testWigiliaPicksUpInDecember() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        let upcoming = service.upcoming(from: date("2026-12-19T08:00:00Z"), lookahead: 7)
        XCTAssertEqual(upcoming?.event.id, "wigilia")
        XCTAssertEqual(upcoming?.daysAway, 5)
    }

    func testReturnsNilWhenNothingWithinWindow() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        let upcoming = service.upcoming(from: date("2026-05-12T08:00:00Z"), lookahead: 7)
        XCTAssertNil(upcoming, "May has no events in the 7-day window")
    }

    func testCalendarReturnsAtLeastOneOfEachEventOverYear() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        let upcoming = service.calendar(from: date("2026-01-01T00:00:00Z"), within: 12)
        let ids = Set(upcoming.map(\.event.id))
        XCTAssertEqual(ids, Set(CulturalEvent.catalog.map(\.id)))
    }

    func testTodayBadgeFiresOnEventDay() {
        let service = CulturalEventService(calendar: Self.utcCalendar)
        let upcoming = service.upcoming(from: date("2026-12-24T08:00:00Z"), lookahead: 1)
        XCTAssertEqual(upcoming?.event.id, "wigilia")
        XCTAssertTrue(upcoming?.isToday == true)
    }
}
