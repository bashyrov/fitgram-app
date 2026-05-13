import XCTest

@testable import Mealgram

final class ProfileStatsCardLabelTests: XCTestCase {

    func testZeroDaysShowsTodayCopy() {
        XCTAssertEqual(ProfileStatsCard.daysWithUsLabel(0), "Dzisiaj dołączyłeś")
    }

    func testOneDayIsSingular() {
        XCTAssertEqual(ProfileStatsCard.daysWithUsLabel(1), "1 dzień z nami")
    }

    func testSeveralDaysIsPlural() {
        XCTAssertEqual(ProfileStatsCard.daysWithUsLabel(2), "2 dni z nami")
        XCTAssertEqual(ProfileStatsCard.daysWithUsLabel(7), "7 dni z nami")
        XCTAssertEqual(ProfileStatsCard.daysWithUsLabel(365), "365 dni z nami")
    }

    func testDaysSinceHandlesPastDate() throws {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)) ?? Date()
        let then = try XCTUnwrap(calendar.date(byAdding: .day, value: -5, to: now))
        XCTAssertEqual(ProfileStatsCard.daysSince(then, now: now), 5)
    }

    func testDaysSinceReturnsNilForFutureDate() throws {
        let calendar = Calendar.current
        let now = calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)) ?? Date()
        let future = try XCTUnwrap(calendar.date(byAdding: .day, value: 3, to: now))
        XCTAssertNil(ProfileStatsCard.daysSince(future, now: now))
    }
}
