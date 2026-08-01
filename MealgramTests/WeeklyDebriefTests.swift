import XCTest

@testable import Mealgram

final class WeeklyDebriefTests: XCTestCase {
    private static let now = Date(timeIntervalSince1970: 1_715_500_000)
    private let generator = RuleBasedCoach()

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("pl", forKey: "app.language")
        Bundle.setLanguage("pl")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "app.language")
        super.tearDown()
    }

    private func context(
        weekCalorieDays: Int,
        weekProteinDays: Int = 0,
        daysLogged: Int = 0,
        streakCurrent: Int = 0,
        dailyCalories: [Double] = [],
        todayKcal: Double = 1200,
        entryCount: Int = 2,
        hour: Int = 12
    ) -> CoachContext {
        CoachContext(
            goals: .init(calorieGoalKcal: 2000, proteinGoalGrams: 120),
            today: .init(
                caloriesKcal: todayKcal,
                proteinGrams: 40,
                carbsGrams: 0, fatGrams: 0,
                entryCount: entryCount,
                lastLoggedAt: nil
            ),
            week: .init(
                dailyCalorieAverages: dailyCalories,
                dailyProteinAverages: [],
                daysWithAnyEntry: daysLogged,
                daysHittingProteinGoal: weekProteinDays,
                daysWithinCalorieGoal: weekCalorieDays
            ),
            streak: .init(
                current: streakCurrent, longest: streakCurrent,
                freezesAvailable: 0, atRiskToday: false
            ),
            weight: .init(latestKg: nil, deltaKg30Days: nil),
            hourOfDay: hour,
            hasOngoingCulturalEvent: false
        )
    }

    func testHeadlineEscalatesWithCalorieDays() async {
        let cudowny = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 6),
            generator: generator, now: Self.now
        )
        XCTAssertEqual(cudowny.headline, "Cudowny tydzień")

        let solidny = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 4),
            generator: generator, now: Self.now
        )
        XCTAssertEqual(solidny.headline, "Solidny tydzień")

        let mieszany = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 2),
            generator: generator, now: Self.now
        )
        XCTAssertEqual(mieszany.headline, "Mieszany tydzień")

        let rytm = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 1),
            generator: generator, now: Self.now
        )
        XCTAssertEqual(rytm.headline, "Spróbujmy łapać rytm")
    }

    func testStatsContainAllFiveKinds() async {
        let debrief = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 4, weekProteinDays: 2, daysLogged: 6, streakCurrent: 3),
            generator: generator, now: Self.now
        )
        let kinds = Set(debrief.stats.map { $0.kind })
        XCTAssertEqual(kinds, Set(WeeklyDebriefStatKind.allKinds))
    }

    func testAverageCaloriesUsesWeekArray() async {
        let values: [Double] = [2000, 1800, 1600, 2200, 1900, 1700, 2000]
        let debrief = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 5, dailyCalories: values),
            generator: generator, now: Self.now
        )
        let avg = values.reduce(0, +) / Double(values.count)
        guard let stat = debrief.stats.first(where: { $0.kind == .avgCalories }) else {
            return XCTFail("avgCalories stat missing")
        }
        XCTAssertEqual(stat.value, "\(Int(avg)) kcal")
    }

    func testInsightsPopulatedFromGenerator() async {
        let debrief = await WeeklyDebrief.from(
            context: context(weekCalorieDays: 6, streakCurrent: 7),
            generator: generator, now: Self.now
        )
        XCTAssertFalse(debrief.insights.isEmpty)
    }
}

extension WeeklyDebriefStatKind {
    fileprivate static let allKinds: [WeeklyDebriefStatKind] = [
        .avgCalories, .calorieDaysOnTarget, .proteinDaysHit, .daysLogged, .currentStreak,
    ]
}
