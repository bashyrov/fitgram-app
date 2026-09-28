import XCTest

@testable import Fitgram

final class CoachInsightCacheTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "CoachInsightCacheTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let weekStart = Date(timeIntervalSince1970: 1_790_000_000)

    private func context(
        todayKcal: Double = 800, entryCount: Int = 2, water: [Int] = [500], hour: Int = 9
    ) -> CoachContext {
        CoachContext(
            goals: .init(calorieGoalKcal: 2000, proteinGoalGrams: 120),
            today: .init(
                caloriesKcal: todayKcal, proteinGrams: 40, carbsGrams: 90, fatGrams: 20,
                entryCount: entryCount, lastLoggedAt: nil
            ),
            week: .init(
                startAt: weekStart,
                endAt: weekStart.addingTimeInterval(7 * 86_400),
                dailyCalorieAverages: [1900, todayKcal],
                dailyProteinAverages: [110, 40],
                dailyWaterMl: water,
                daysWithAnyEntry: 2,
                daysHittingProteinGoal: 1,
                daysWithinCalorieGoal: 1
            ),
            streak: .init(current: 2, longest: 5, freezesAvailable: 1, atRiskToday: false),
            weight: .init(latestKg: 72.4, deltaKg30Days: -0.8),
            hourOfDay: hour,
            hasOngoingCulturalEvent: false,
            memory: []
        )
    }

    // MARK: - Signature

    func testSignatureIgnoresHourWithinSameDayPart() {
        XCTAssertEqual(context(hour: 8).aiSignature, context(hour: 11).aiSignature)
        XCTAssertEqual(context(hour: 12).aiSignature, context(hour: 17).aiSignature)
    }

    func testSignatureChangesWithDayPart() {
        XCTAssertNotEqual(context(hour: 11).aiSignature, context(hour: 12).aiSignature)
        XCTAssertNotEqual(context(hour: 17).aiSignature, context(hour: 18).aiSignature)
    }

    func testSignatureChangesWhenUserLogsSomething() {
        let base = context()
        XCTAssertNotEqual(base.aiSignature, context(todayKcal: 1250, entryCount: 3).aiSignature)
        XCTAssertNotEqual(base.aiSignature, context(water: [750]).aiSignature)
    }

    // MARK: - Store

    func testStoreReturnsInsightsOnlyForMatchingDayLocaleAndSignature() {
        let store = CoachInsightStore(defaults: defaults)
        let insights = [CoachInsight(tone: .suggestion, headline: "Białko", body: "Dorzuć skyr.")]
        store.save(insights, userRemoteID: "u", dateKey: "2026-09-28", locale: "pl", signature: "abc")

        XCTAssertEqual(
            store.load(userRemoteID: "u", dateKey: "2026-09-28", locale: "pl", signature: "abc"), insights)
        XCTAssertNil(store.load(userRemoteID: "u", dateKey: "2026-09-29", locale: "pl", signature: "abc"))
        XCTAssertNil(store.load(userRemoteID: "u", dateKey: "2026-09-28", locale: "en", signature: "abc"))
        XCTAssertNil(store.load(userRemoteID: "u", dateKey: "2026-09-28", locale: "pl", signature: "def"))
        XCTAssertNil(store.load(userRemoteID: "other", dateKey: "2026-09-28", locale: "pl", signature: "abc"))
    }

    func testStoreKeepsOneEntryPerUser() {
        let store = CoachInsightStore(defaults: defaults)
        let first = [CoachInsight(tone: .nudge, headline: "A", body: "a")]
        let second = [CoachInsight(tone: .celebration, headline: "B", body: "b")]
        store.save(first, userRemoteID: "u", dateKey: "d", locale: "pl", signature: "1")
        store.save(second, userRemoteID: "u", dateKey: "d", locale: "pl", signature: "2")

        XCTAssertNil(store.load(userRemoteID: "u", dateKey: "d", locale: "pl", signature: "1"))
        XCTAssertEqual(store.load(userRemoteID: "u", dateKey: "d", locale: "pl", signature: "2"), second)
        let keys = defaults.dictionaryRepresentation().keys.filter { $0.hasPrefix("coach.insights.") }
        XCTAssertEqual(keys.count, 1)
    }
}
