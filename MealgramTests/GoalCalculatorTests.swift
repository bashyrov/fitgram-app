import XCTest

@testable import Mealgram

final class GoalCalculatorTests: XCTestCase {
    private func input(
        height: Int = 170,
        weight: Double = 70,
        age: Int = 30,
        sex: BiologicalSex = .female,
        activity: ActivityLevel = .moderate,
        goal: GoalKind = .maintain
    ) -> GoalCalculator.Input {
        GoalCalculator.Input(
            heightCm: height, weightKg: weight, age: age,
            biologicalSex: sex, activityLevel: activity, goal: goal
        )
    }

    func testReferenceFemaleMaintain() throws {
        // 170cm / 70kg / 30y / female / moderate / maintain
        // BMR = 10*70 + 6.25*170 − 5*30 − 161 = 700 + 1062.5 − 150 − 161 = 1451.5
        // TDEE = 1451.5 * 1.55 = ~2249.8 → 2250 (rounded to 10)
        let output = try XCTUnwrap(GoalCalculator.calculate(from: input()))
        XCTAssertEqual(output.dailyCalorieGoalKcal, 2250)
    }

    func testReferenceMaleLose() throws {
        // 180cm / 80kg / 35y / male / active / lose
        // BMR = 10*80 + 6.25*180 − 5*35 + 5 = 800 + 1125 − 175 + 5 = 1755
        // TDEE = 1755 * 1.725 = ~3027.4
        // Lose: 3027.4 − 500 = 2527.4 → 2530
        let output = try XCTUnwrap(
            GoalCalculator.calculate(
                from: input(
                    height: 180, weight: 80, age: 35,
                    sex: .male, activity: .active, goal: .lose
                )
            )
        )
        XCTAssertEqual(output.dailyCalorieGoalKcal, 2530)
    }

    func testMacroSplitFollowsTwentyFiveFiftyTwentyFive() throws {
        let output = try XCTUnwrap(GoalCalculator.calculate(from: input()))
        // TDEE 2249.825 (pre-rounding) → protein 562/4 ≈ 141, carbs
        // 1124.9/4 ≈ 281, fat 562/9 ≈ 62.
        XCTAssertEqual(output.proteinGoalGrams, 141)
        XCTAssertEqual(output.carbsGoalGrams, 281)
        XCTAssertEqual(output.fatGoalGrams, 62)
    }

    func testUndisclosedSexSplitsTheDifference() throws {
        let female = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .female)))
        let male = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .male)))
        let undisclosed = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .undisclosed)))
        XCTAssertTrue(undisclosed.dailyCalorieGoalKcal > female.dailyCalorieGoalKcal)
        XCTAssertTrue(undisclosed.dailyCalorieGoalKcal < male.dailyCalorieGoalKcal)
    }

    func testGoalLoseSubtracts500FromTdee() {
        // Same inputs differ only by goal — lose should be 500 kcal less
        // than maintain.
        let maintain = GoalCalculator.calculate(from: input(goal: .maintain))?.dailyCalorieGoalKcal ?? 0
        let lose = GoalCalculator.calculate(from: input(goal: .lose))?.dailyCalorieGoalKcal ?? 0
        XCTAssertEqual(maintain - lose, 500)
    }

    func testGoalGainAdds300ToTdee() {
        let maintain = GoalCalculator.calculate(from: input(goal: .maintain))?.dailyCalorieGoalKcal ?? 0
        let gain = GoalCalculator.calculate(from: input(goal: .gain))?.dailyCalorieGoalKcal ?? 0
        XCTAssertEqual(gain - maintain, 300)
    }

    func testActivityScalesTdee() {
        let sedentary = GoalCalculator.calculate(from: input(activity: .sedentary))?.dailyCalorieGoalKcal ?? 0
        let veryActive =
            GoalCalculator.calculate(
                from: input(activity: .veryActive)
            )?.dailyCalorieGoalKcal ?? 0
        XCTAssertTrue(veryActive > sedentary)
    }

    func testZeroHeightReturnsNil() {
        XCTAssertNil(GoalCalculator.calculate(from: input(height: 0)))
    }

    func testZeroAgeReturnsNil() {
        XCTAssertNil(GoalCalculator.calculate(from: input(age: 0)))
    }
}
