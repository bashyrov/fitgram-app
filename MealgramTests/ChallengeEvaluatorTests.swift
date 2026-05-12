import XCTest

@testable import Mealgram

@MainActor
final class ChallengeEvaluatorTests: XCTestCase {
    private static func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let utc = TimeZone(secondsFromGMT: 0) else { fatalError("UTC missing") }
        calendar.timeZone = utc
        return calendar
    }

    private static func meal(
        day offset: Int,
        type: MealType = .lunch,
        source: MealSource = .quickDatabase,
        kcal: Double = 600,
        protein: Double = 30,
        item: String = "Schabowy"
    ) -> MealEntry {
        guard let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) else {
            fatalError("date math")
        }
        return MealEntry(
            consumedAt: date,
            mealType: type,
            source: source,
            items: [
                FoodItem(
                    name: item,
                    quantityGrams: 200,
                    caloriesKcal: kcal,
                    proteinGrams: protein,
                    carbsGrams: 0,
                    fatGrams: 0
                )
            ]
        )
    }

    private func input(meals: [MealEntry]) -> ChallengeEvaluator.Input {
        ChallengeEvaluator.Input(
            meals: meals,
            calorieGoal: 2000,
            proteinGoal: 100,
            calendar: Self.utcCalendar()
        )
    }

    func testLoggedDaysCountsDistinctCalendarDays() {
        let meals = [
            Self.meal(day: 0),
            Self.meal(day: 0),
            Self.meal(day: -1),
            Self.meal(day: -2),
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .loggedDays(target: 7)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 3)
    }

    func testProteinDaysHitRequiresNinetyPercentOfGoal() {
        let meals = [
            Self.meal(day: 0, protein: 100),  // 100 % — hits
            Self.meal(day: -1, protein: 90),  // 90 % — hits (threshold 90)
            Self.meal(day: -2, protein: 89),  // 89 % — miss
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .proteinDaysHit(target: 5)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 2)
    }

    func testCalorieDaysOnTargetUsesFifteenPercentBand() {
        let meals = [
            Self.meal(day: 0, kcal: 2000),  // 100 % — in
            Self.meal(day: -1, kcal: 1800),  // 90 %  — in (band 85-115)
            Self.meal(day: -2, kcal: 1600),  // 80 %  — out
            Self.meal(day: -3, kcal: 2400),  // 120 % — out
            Self.meal(day: -4, kcal: 2300),  // 115 % — in (exact upper bound)
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .calorieDaysOnTarget(target: 5)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 3)
    }

    func testBreakfastDaysOnlyCountsBreakfastEntries() {
        let meals = [
            Self.meal(day: 0, type: .breakfast),
            Self.meal(day: 0, type: .lunch),  // same day, not breakfast
            Self.meal(day: -1, type: .breakfast),
            Self.meal(day: -2, type: .snack),  // no breakfast that day
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .breakfastDays(target: 5)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 2)
    }

    func testDistinctFoodsIsCaseInsensitive() {
        let meals = [
            Self.meal(day: 0, item: "Owsianka"),
            Self.meal(day: -1, item: "owsianka"),  // dupe
            Self.meal(day: -1, item: "Jogurt"),
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .distinctFoods(target: 15)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 2)
    }

    func testRecipeCooksCountsOnlyRecipeSourcedMeals() {
        let meals = [
            Self.meal(day: 0, source: .recipe),
            Self.meal(day: -1, source: .recipe),
            Self.meal(day: -1, source: .quickDatabase),
        ]
        let progress = ChallengeEvaluator.progress(
            for: Challenge(
                id: "x", title: "", body: "", systemImage: "",
                rule: .recipeCooks(target: 2)
            ),
            input: input(meals: meals)
        )
        XCTAssertEqual(progress, 2)
    }

    func testEvaluateReturnsOneEntryPerCatalogChallenge() {
        let progress = ChallengeEvaluator.evaluate(
            ChallengeCatalog.all,
            with: input(meals: [Self.meal(day: 0)])
        )
        XCTAssertEqual(progress.count, ChallengeCatalog.all.count)
    }
}
