import XCTest

@testable import Mealgram

final class NotificationPlannerTests: XCTestCase {
    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad iso \(iso)") }
        return date
    }

    func testDefaultPreferencesNoMealsSchedulesAllThree() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z")
            )
        )
        XCTAssertEqual(plan.morningGreeting, DateComponents(hour: 8, minute: 0))
        XCTAssertEqual(plan.streakRisk, DateComponents(hour: 20, minute: 30))
        XCTAssertFalse(plan.streakRiskSuggestsFreeze)
        XCTAssertEqual(plan.eveningSummary, DateComponents(hour: 21, minute: 0))
    }

    func testHasLoggedTodaySilencesMorningAndStreakRisk() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: true,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T15:00:00Z")
            )
        )
        XCTAssertNil(plan.morningGreeting)
        XCTAssertNil(plan.streakRisk)
        XCTAssertFalse(plan.streakRiskSuggestsFreeze)
        XCTAssertEqual(plan.eveningSummary, DateComponents(hour: 21, minute: 0))
    }

    func testAllOffPreferencesProducesEmptyPlan() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .allOff,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z")
            )
        )
        XCTAssertEqual(plan, .empty)
        XCTAssertNil(plan.goalWeight)
    }

    func testIndividualOptOutOnlyDropsThatChannel() {
        var prefs = NotificationPlanner.Preferences.default
        prefs.streakRisk = false
        let plan = NotificationPlanner.plan(
            .init(
                preferences: prefs,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z")
            )
        )
        XCTAssertNotNil(plan.morningGreeting)
        XCTAssertNil(plan.streakRisk)
        XCTAssertNotNil(plan.eveningSummary)
    }

    func testGoalWeightFiresWhenActiveGoalAndNotLogged() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z"),
                hasActiveGoal: true,
                hasLoggedGoalWeightToday: false
            )
        )
        XCTAssertEqual(plan.goalWeight, DateComponents(hour: 9, minute: 0))
    }

    func testGoalWeightSilentWhenAlreadyLoggedToday() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z"),
                hasActiveGoal: true,
                hasLoggedGoalWeightToday: true
            )
        )
        XCTAssertNil(plan.goalWeight)
    }

    func testGoalWeightSilentWhenNoActiveGoal() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z"),
                hasActiveGoal: false,
                hasLoggedGoalWeightToday: false
            )
        )
        XCTAssertNil(plan.goalWeight)
    }

    func testGoalWeightHonoursCustomTime() {
        var prefs = NotificationPlanner.Preferences.default
        prefs.goalWeightHour = 7
        prefs.goalWeightMinute = 30
        let plan = NotificationPlanner.plan(
            .init(
                preferences: prefs,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T07:00:00Z"),
                hasActiveGoal: true,
                hasLoggedGoalWeightToday: false
            )
        )
        XCTAssertEqual(plan.goalWeight, DateComponents(hour: 7, minute: 30))
    }

    func testEveningSummaryFiresEvenWhenLogged() {
        var prefs = NotificationPlanner.Preferences.allOff
        prefs.eveningSummary = true
        let plan = NotificationPlanner.plan(
            .init(
                preferences: prefs,
                hasLoggedToday: true,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T19:00:00Z")
            )
        )
        XCTAssertNil(plan.morningGreeting)
        XCTAssertNil(plan.streakRisk)
        XCTAssertEqual(plan.eveningSummary, DateComponents(hour: 21, minute: 0))
    }

    func testStreakRiskSuggestsFreezeWhenAvailable() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T19:00:00Z"),
                currentStreakLength: 8,
                freezesAvailable: 1,
                hasProtectedStreakToday: false
            )
        )
        XCTAssertEqual(plan.streakRisk, DateComponents(hour: 20, minute: 30))
        XCTAssertTrue(plan.streakRiskSuggestsFreeze)
    }

    func testProtectedStreakTodaySilencesRiskReminder() {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: .default,
                hasLoggedToday: false,
                calendar: Self.utcCalendar(),
                now: Self.date("2026-05-12T19:00:00Z"),
                currentStreakLength: 8,
                freezesAvailable: 1,
                hasProtectedStreakToday: true
            )
        )
        XCTAssertNil(plan.streakRisk)
        XCTAssertFalse(plan.streakRiskSuggestsFreeze)
    }
}
