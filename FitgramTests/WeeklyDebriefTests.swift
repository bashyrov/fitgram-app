import XCTest

@testable import Fitgram

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
            hasOngoingCulturalEvent: false,
            memory: []
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

    func testStatsContainAllKinds() async {
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

    func testFallbackWeeklyDebriefUsesSelectedRussianLanguage() async {
        UserDefaults.standard.set("ru", forKey: "app.language")
        Bundle.setLanguage("ru")

        let debrief = await WeeklyDebrief.from(
            context: context(
                weekCalorieDays: 1,
                weekProteinDays: 1,
                daysLogged: 3,
                dailyCalories: [2100, 1900, 2600, 1700, 0, 0, 0]
            ),
            generator: EmptyWeeklyGenerator(),
            now: Self.now
        )

        XCTAssertEqual(debrief.headline, "Возвращаем ритм")
        XCTAssertTrue(debrief.stats.contains { $0.caption.contains("среднем") })
        XCTAssertTrue(debrief.sections.contains { $0.body.contains("калор") || $0.title == "Калории" })
        XCTAssertFalse(debrief.nextWeekRules.contains { $0.contains("Start the first meal") })
    }
}

extension WeeklyDebriefStatKind {
    fileprivate static let allKinds: [WeeklyDebriefStatKind] = [
        .avgCalories, .calorieDaysOnTarget, .proteinDaysHit, .daysLogged, .currentStreak, .avgWater,
        .workoutMinutes,
    ]
}

private struct EmptyWeeklyGenerator: CoachInsightGenerator {
    func generate(for context: CoachContext) async -> [CoachInsight] { [] }

    func generateDailyPlan(for context: CoachContext, now: Date) async -> DailyOlaPlan {
        DailyOlaPlanBuilder.build(context: context, now: now)
    }

    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult {
        WeeklyDebriefAIResult(headline: nil, sections: [], nextWeekRules: [], insights: [])
    }
}
