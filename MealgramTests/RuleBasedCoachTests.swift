import XCTest

@testable import Mealgram

final class RuleBasedCoachTests: XCTestCase {
    private let coach = RuleBasedCoach()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("pl", forKey: "app.language")
        Bundle.setLanguage("pl")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "app.language")
        super.tearDown()
    }

    // MARK: - Helpers

    private func context(
        calorieGoal: Int = 2000,
        proteinGoal: Int = 120,
        todayKcal: Double = 0,
        todayProtein: Double = 0,
        entryCount: Int = 0,
        weekDays: Int = 0,
        weekProteinDays: Int = 0,
        weekCalorieDays: Int = 0,
        streakCurrent: Int = 0,
        streakLongest: Int = 0,
        atRisk: Bool = false,
        weight30Delta: Double? = nil,
        hour: Int = 12
    ) -> CoachContext {
        CoachContext(
            goals: .init(calorieGoalKcal: calorieGoal, proteinGoalGrams: proteinGoal),
            today: .init(
                caloriesKcal: todayKcal,
                proteinGrams: todayProtein,
                carbsGrams: 0,
                fatGrams: 0,
                entryCount: entryCount,
                lastLoggedAt: nil
            ),
            week: .init(
                dailyCalorieAverages: [],
                dailyProteinAverages: [],
                daysWithAnyEntry: weekDays,
                daysHittingProteinGoal: weekProteinDays,
                daysWithinCalorieGoal: weekCalorieDays
            ),
            streak: .init(
                current: streakCurrent,
                longest: streakLongest,
                freezesAvailable: 0,
                atRiskToday: atRisk
            ),
            weight: .init(latestKg: nil, deltaKg30Days: weight30Delta),
            hourOfDay: hour,
            hasOngoingCulturalEvent: false
        )
    }

    // MARK: - Streak milestone

    func testSevenDayStreakCelebrated() async {
        let result = await coach.generate(for: context(streakCurrent: 7))
        XCTAssertEqual(result.first?.tone, .celebration)
        XCTAssertTrue(result.first?.body.contains("7") ?? false)
    }

    func testFiveDayStreakNotCelebrated() async {
        let result = await coach.generate(for: context(todayKcal: 800, entryCount: 1, streakCurrent: 5))
        XCTAssertNotEqual(result.first?.headline, "Brawo!")
    }

    // MARK: - Streak-at-risk

    func testStreakAtRiskAfter6PMNudges() async {
        let result = await coach.generate(for: context(streakCurrent: 4, atRisk: true, hour: 19))
        XCTAssertEqual(result.first?.tone, .nudge)
        XCTAssertEqual(result.first?.actionKind, .openScanner)
    }

    func testStreakAtRiskBefore6PMDoesNotNudge() async {
        let result = await coach.generate(for: context(streakCurrent: 4, atRisk: true, hour: 13))
        XCTAssertNotEqual(result.first?.tone, .nudge)
    }

    // MARK: - Protein suggestion

    func testLowProteinAfterLunchSuggests() async {
        let result = await coach.generate(
            for: context(
                proteinGoal: 100,
                todayKcal: 600,
                todayProtein: 20,
                entryCount: 1,
                hour: 15
            )
        )
        let insight = result.first { $0.tone == .suggestion }
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.actionKind, .openQuickDB)
    }

    func testProteinSuggestionDoesNotFireBeforeLunch() async {
        let result = await coach.generate(
            for: context(
                proteinGoal: 100, todayKcal: 600, todayProtein: 20,
                entryCount: 1, hour: 11
            )
        )
        XCTAssertNil(result.first { $0.actionKind == .openQuickDB })
    }

    // MARK: - Calorie overshoot

    func testOver120PercentCaloriesNudges() async {
        let result = await coach.generate(
            for: context(calorieGoal: 1800, todayKcal: 2300, entryCount: 3, hour: 19)
        )
        XCTAssertTrue(result.contains { $0.tone == .nudge && $0.headline.contains("bogato") })
    }

    // MARK: - Welcome fallback

    func testEmptyEarlyMorningProducesGreeting() async {
        let result = await coach.generate(for: context(hour: 7))
        XCTAssertFalse(result.isEmpty)
        XCTAssertEqual(result.first?.actionKind, .openScanner)
    }

    // MARK: - Weight progress

    func testWeightDropCelebrated() async {
        let result = await coach.generate(for: context(weight30Delta: -1.5))
        XCTAssertTrue(result.contains { $0.tone == .celebration && $0.headline.contains("trajektoria") })
    }

    func testWeightSpikeIsEncouragementWithAction() async {
        let result = await coach.generate(for: context(weight30Delta: 1.4))
        let insight = result.first { $0.actionKind == .openWeightLog }
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.tone, .encouragement)
    }

    // MARK: - Balanced week

    func testFiveOutOfSevenDaysCelebrated() async {
        let result = await coach.generate(
            for: context(
                todayKcal: 800, entryCount: 1,
                weekDays: 6, weekCalorieDays: 5, streakCurrent: 6
            )
        )
        XCTAssertTrue(result.contains { $0.headline.contains("Świetny tydzień") })
    }

    // MARK: - Morning protein

    func testMorningProteinFiresWhenBreakfastLightOnProtein() async {
        let result = await coach.generate(
            for: context(todayKcal: 250, todayProtein: 5, entryCount: 1, hour: 8)
        )
        XCTAssertTrue(result.contains { $0.headline.contains("Białko na śniadanie") })
    }

    func testMorningProteinSilentAfterEnoughProtein() async {
        let result = await coach.generate(
            for: context(todayKcal: 250, todayProtein: 25, entryCount: 1, hour: 8)
        )
        XCTAssertFalse(result.contains { $0.headline.contains("Białko na śniadanie") })
    }

    // MARK: - Afternoon momentum

    func testAfternoonMomentumFiresMidDayInRange() async {
        let result = await coach.generate(
            for: context(todayKcal: 1100, entryCount: 2, hour: 15)
        )
        XCTAssertTrue(result.contains { $0.headline.contains("Dobre tempo") })
    }

    func testAfternoonMomentumSilentBefore14() async {
        let result = await coach.generate(
            for: context(todayKcal: 1100, entryCount: 2, hour: 12)
        )
        XCTAssertFalse(result.contains { $0.headline.contains("Dobre tempo") })
    }

    // MARK: - Max insights bound

    func testNeverReturnsMoreThanThree() async {
        // All-fire context: 7-day streak + weight drop + week + at-risk would be 4+
        let result = await coach.generate(
            for: context(
                weekDays: 7, weekCalorieDays: 6,
                streakCurrent: 7,
                atRisk: false,
                weight30Delta: -1.5
            )
        )
        XCTAssertLessThanOrEqual(result.count, 3)
    }
}
