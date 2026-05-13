import XCTest

@testable import Mealgram

final class GoalCalculatorTests: XCTestCase {
    private func input(
        height: Int = 170,
        weight: Double = 70,
        age: Int = 30,
        sex: BiologicalSex = .female,
        activity: ActivityLevel = .moderate,
        goal: GoalKind = .maintain,
        pace: Double? = nil
    ) -> GoalCalculator.Input {
        GoalCalculator.Input(
            heightCm: height,
            weightKg: weight,
            age: age,
            biologicalSex: sex,
            activityLevel: activity,
            goal: goal,
            paceKgPerWeek: pace
        )
    }

    // MARK: - Legacy `calculate` reference numbers (kcal)

    func testReferenceFemaleMaintain() throws {
        // 170cm / 70kg / 30y / female / moderate / maintain
        // BMR = 10*70 + 6.25*170 − 5*30 − 161 = 1451.5
        // TDEE = 1451.5 * 1.55 = 2249.825 → 2250
        let output = try XCTUnwrap(GoalCalculator.calculate(from: input()))
        XCTAssertEqual(output.dailyCalorieGoalKcal, 2250)
    }

    func testReferenceMaleLose() throws {
        // 180cm / 80kg / 35y / male / active / lose (no pace → legacy −500)
        // BMR = 1755, TDEE = 1755 * 1.725 = 3027.375
        // Lose: 3027.375 − 500 = 2527.4 → 2530
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

    func testMacroSplitMaintainIs25_45_30() throws {
        let output = try XCTUnwrap(GoalCalculator.calculate(from: input()))
        // 2249.825 (pre-rounding) split 25/45/30
        XCTAssertEqual(output.proteinGoalGrams, 141)
        XCTAssertEqual(output.carbsGoalGrams, 253)
        XCTAssertEqual(output.fatGoalGrams, 75)
    }

    func testMacroSplitLoseShiftsProteinUp() throws {
        let maintain = try XCTUnwrap(GoalCalculator.calculate(from: input(goal: .maintain)))
        let lose = try XCTUnwrap(GoalCalculator.calculate(from: input(goal: .lose)))
        // Even at fewer calories, lose path uses 30% protein vs 25% for
        // maintain — protein grams should be close despite the deficit.
        XCTAssertGreaterThan(
            Double(lose.proteinGoalGrams) / Double(lose.dailyCalorieGoalKcal),
            Double(maintain.proteinGoalGrams) / Double(maintain.dailyCalorieGoalKcal)
        )
    }

    func testUndisclosedSexSplitsTheDifference() throws {
        let female = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .female)))
        let male = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .male)))
        let undisclosed = try XCTUnwrap(GoalCalculator.calculate(from: input(sex: .undisclosed)))
        XCTAssertTrue(undisclosed.dailyCalorieGoalKcal > female.dailyCalorieGoalKcal)
        XCTAssertTrue(undisclosed.dailyCalorieGoalKcal < male.dailyCalorieGoalKcal)
    }

    func testGoalLoseSubtracts500FromTdeeWhenPaceMissing() {
        let maintain = GoalCalculator.calculate(from: input(goal: .maintain))?.dailyCalorieGoalKcal ?? 0
        let lose = GoalCalculator.calculate(from: input(goal: .lose))?.dailyCalorieGoalKcal ?? 0
        XCTAssertEqual(maintain - lose, 500)
    }

    func testGoalGainAdds300ToTdeeWhenPaceMissing() {
        let maintain = GoalCalculator.calculate(from: input(goal: .maintain))?.dailyCalorieGoalKcal ?? 0
        let gain = GoalCalculator.calculate(from: input(goal: .gain))?.dailyCalorieGoalKcal ?? 0
        XCTAssertEqual(gain - maintain, 300)
    }

    func testActivityScalesTdee() {
        let sedentary = GoalCalculator.calculate(from: input(activity: .sedentary))?.dailyCalorieGoalKcal ?? 0
        let veryActive = GoalCalculator.calculate(
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

    func testZeroWeightReturnsNil() {
        XCTAssertNil(GoalCalculator.calculate(from: input(weight: 0)))
    }

    // MARK: - Pace-based deficit (spec: 1100 kcal per kg/week)

    func testPaceQuarterKgLosesAround275() throws {
        let none = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .lose, pace: nil)))
        let paced = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .lose, pace: 0.25)))
        let maintain = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .maintain)))
        XCTAssertEqual(maintain.dailyCalorieGoalKcal - paced.dailyCalorieGoalKcal, 280, accuracy: 10)
        XCTAssertNotEqual(none.dailyCalorieGoalKcal, paced.dailyCalorieGoalKcal)
    }

    func testPaceHalfKgLosesAround550() throws {
        let paced = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .lose, pace: 0.5)))
        let maintain = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .maintain)))
        XCTAssertEqual(maintain.dailyCalorieGoalKcal - paced.dailyCalorieGoalKcal, 550, accuracy: 10)
    }

    func testPaceOneKgGainsAround1100() throws {
        let paced = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(weight: 80, sex: .male, goal: .gain, pace: 1.0)))
        let maintain = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(weight: 80, sex: .male, goal: .maintain)))
        XCTAssertEqual(paced.dailyCalorieGoalKcal - maintain.dailyCalorieGoalKcal, 1100, accuracy: 10)
    }

    func testPaceIgnoredForMaintainGoal() throws {
        let withPace = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .maintain, pace: 0.5)))
        let withoutPace = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .maintain)))
        XCTAssertEqual(withPace.dailyCalorieGoalKcal, withoutPace.dailyCalorieGoalKcal)
    }

    func testNegativePaceTreatedAsNil() throws {
        let weird = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .lose, pace: -0.5)))
        let legacy = try XCTUnwrap(GoalCalculator.calculateTargets(from: input(goal: .lose, pace: nil)))
        XCTAssertEqual(weird.dailyCalorieGoalKcal, legacy.dailyCalorieGoalKcal)
    }

    // MARK: - Safety floor (1200 F / 1500 M / 1350 undisclosed)

    func testAggressivePaceCappedAtFemaleFloor() throws {
        // 60kg female, sedentary, lose at 1 kg/wk would compute well
        // under 1200 — must cap and flag.
        let probe = input(
            weight: 60, age: 40, sex: .female,
            activity: .sedentary, goal: .lose, pace: 1.0
        )
        let targets = try XCTUnwrap(GoalCalculator.calculateTargets(from: probe))
        XCTAssertEqual(targets.dailyCalorieGoalKcal, 1200)
        XCTAssertTrue(targets.hitSafetyFloor)
    }

    func testAggressivePaceCappedAtMaleFloor() throws {
        let probe = input(
            weight: 70, age: 40, sex: .male,
            activity: .sedentary, goal: .lose, pace: 1.0
        )
        let targets = try XCTUnwrap(GoalCalculator.calculateTargets(from: probe))
        XCTAssertGreaterThanOrEqual(targets.dailyCalorieGoalKcal, 1500)
        XCTAssertTrue(targets.hitSafetyFloor)
    }

    func testSafeDeficitDoesNotFlagFloor() throws {
        let probe = input(
            weight: 80, sex: .male, activity: .active,
            goal: .lose, pace: 0.5
        )
        let targets = try XCTUnwrap(GoalCalculator.calculateTargets(from: probe))
        XCTAssertFalse(targets.hitSafetyFloor)
        XCTAssertGreaterThan(targets.dailyCalorieGoalKcal, 1500)
    }

    func testMaintainNeverHitsFloor() throws {
        // 30kg female (extreme low) — maintain shouldn't trip the floor
        // because there's no deficit subtraction.
        let probe = input(weight: 30, sex: .female, activity: .sedentary, goal: .maintain)
        let targets = try XCTUnwrap(GoalCalculator.calculateTargets(from: probe))
        XCTAssertFalse(targets.hitSafetyFloor)
    }

    // MARK: - Fiber

    func testFiberClampsToFemaleRange() {
        let lowKcal = GoalCalculator.fiberTarget(forCalories: 1200, sex: .female)
        let highKcal = GoalCalculator.fiberTarget(forCalories: 4000, sex: .female)
        XCTAssertGreaterThanOrEqual(lowKcal, 25)
        XCTAssertLessThanOrEqual(highKcal, 30)
    }

    func testFiberClampsToMaleRange() {
        let lowKcal = GoalCalculator.fiberTarget(forCalories: 1500, sex: .male)
        let highKcal = GoalCalculator.fiberTarget(forCalories: 5000, sex: .male)
        XCTAssertGreaterThanOrEqual(lowKcal, 30)
        XCTAssertLessThanOrEqual(highKcal, 38)
    }

    func testFiberScalesWithCaloriesInRange() {
        let male2000 = GoalCalculator.fiberTarget(forCalories: 2000, sex: .male)
        let male3000 = GoalCalculator.fiberTarget(forCalories: 3000, sex: .male)
        XCTAssertGreaterThanOrEqual(male3000, male2000)
    }

    // MARK: - Water

    func testWaterAtSeventyKgIs2450ml() {
        // Spec example: 70kg → 2450ml
        XCTAssertEqual(GoalCalculator.waterTarget(weightKg: 70), 2450)
    }

    func testWaterRoundsToFifty() {
        // 73kg * 35 = 2555 → rounds to 2550
        XCTAssertEqual(GoalCalculator.waterTarget(weightKg: 73), 2550)
        // 71kg * 35 = 2485 → rounds to 2500
        XCTAssertEqual(GoalCalculator.waterTarget(weightKg: 71), 2500)
    }

    func testWaterScalesWithWeight() {
        let light = GoalCalculator.waterTarget(weightKg: 50)
        let heavy = GoalCalculator.waterTarget(weightKg: 100)
        XCTAssertGreaterThan(heavy, light)
    }

    // MARK: - Activity multipliers

    func testActivityMultiplierMatchesSpec() {
        XCTAssertEqual(GoalCalculator.activityMultiplier(for: .sedentary), 1.2)
        XCTAssertEqual(GoalCalculator.activityMultiplier(for: .light), 1.375)
        XCTAssertEqual(GoalCalculator.activityMultiplier(for: .moderate), 1.55)
        XCTAssertEqual(GoalCalculator.activityMultiplier(for: .active), 1.725)
        XCTAssertEqual(GoalCalculator.activityMultiplier(for: .veryActive), 1.9)
    }

    // MARK: - BMR formula

    func testBmrMaleFormula() {
        // 80kg / 180cm / 30y / male → 10*80 + 6.25*180 − 5*30 + 5 = 1780
        let bmr = GoalCalculator.mifflinStJeorBMR(
            input: input(height: 180, weight: 80, age: 30, sex: .male)
        )
        XCTAssertEqual(bmr, 1780, accuracy: 0.001)
    }

    func testBmrFemaleFormula() {
        // 65kg / 165cm / 28y / female → 10*65 + 6.25*165 − 5*28 − 161 = 1380.25
        let bmr = GoalCalculator.mifflinStJeorBMR(
            input: input(height: 165, weight: 65, age: 28, sex: .female)
        )
        XCTAssertEqual(bmr, 1380.25, accuracy: 0.001)
    }

    func testBmrUndisclosedSitsBetweenMaleAndFemale() {
        let male = GoalCalculator.mifflinStJeorBMR(input: input(sex: .male))
        let female = GoalCalculator.mifflinStJeorBMR(input: input(sex: .female))
        let undisclosed = GoalCalculator.mifflinStJeorBMR(input: input(sex: .undisclosed))
        XCTAssertEqual(undisclosed, (male + female) / 2, accuracy: 1.0)
    }

    // MARK: - Edge cases

    func testMinimumPhysiologicalInputs() {
        // 13y old, smallest allowed height/weight per spec — still valid.
        let out = GoalCalculator.calculateTargets(
            from: input(height: 140, weight: 30, age: 13)
        )
        XCTAssertNotNil(out)
    }

    func testMaximumPhysiologicalInputs() throws {
        let out = try XCTUnwrap(GoalCalculator.calculateTargets(
            from: input(height: 220, weight: 200, age: 100, sex: .male, activity: .veryActive)
        ))
        XCTAssertGreaterThan(out.dailyCalorieGoalKcal, 3000)
    }

    func testFullTargetsBundle() throws {
        let targets = try XCTUnwrap(
            GoalCalculator.calculateTargets(
                from: input(height: 178, weight: 82, age: 32, sex: .male, activity: .moderate, goal: .lose, pace: 0.5)
            )
        )
        XCTAssertGreaterThan(targets.bmr, 0)
        XCTAssertGreaterThan(targets.tdee, targets.bmr)
        XCTAssertGreaterThan(targets.dailyCalorieGoalKcal, 1500)
        XCTAssertGreaterThan(targets.waterGoalMl, 2500)
        XCTAssertGreaterThanOrEqual(targets.fiberGoalGrams, 30)
        XCTAssertLessThanOrEqual(targets.fiberGoalGrams, 38)
    }
}

final class GoalProjectionTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)
    private let start = Date(timeIntervalSince1970: 1_700_000_000)  // fixed reference

    func testProjectionAtHalfKgPerWeek() throws {
        // 80 → 75 (5kg) at 0.5 kg/wk = 10 weeks = 70 days
        let end = try XCTUnwrap(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 80,
                targetWeightKg: 75,
                paceKgPerWeek: 0.5,
                from: start,
                calendar: calendar
            )
        )
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        XCTAssertEqual(days, 70)
    }

    func testProjectionRoundsUp() throws {
        // 80 → 79.6 (0.4kg) at 0.25 kg/wk = 1.6 weeks = 11.2 days → ceil 12
        let end = try XCTUnwrap(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 80,
                targetWeightKg: 79.6,
                paceKgPerWeek: 0.25,
                from: start,
                calendar: calendar
            )
        )
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        XCTAssertEqual(days, 12)
    }

    func testProjectionGainDirection() throws {
        // 70 → 75 (5kg gain) at 0.5 kg/wk = 70 days — same as loss direction
        let end = try XCTUnwrap(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 70,
                targetWeightKg: 75,
                paceKgPerWeek: 0.5,
                from: start,
                calendar: calendar
            )
        )
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        XCTAssertEqual(days, 70)
    }

    func testZeroPaceReturnsNil() {
        XCTAssertNil(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 80,
                targetWeightKg: 75,
                paceKgPerWeek: 0,
                from: start,
                calendar: calendar
            )
        )
    }

    func testNegativePaceReturnsNil() {
        XCTAssertNil(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 80,
                targetWeightKg: 75,
                paceKgPerWeek: -0.5,
                from: start,
                calendar: calendar
            )
        )
    }

    func testTargetEqualsCurrentReturnsNil() {
        XCTAssertNil(
            GoalProjection.estimatedEndDate(
                currentWeightKg: 80,
                targetWeightKg: 80,
                paceKgPerWeek: 0.5,
                from: start,
                calendar: calendar
            )
        )
    }
}
