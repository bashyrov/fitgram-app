import XCTest

@testable import Mealgram

final class RuleBasedRecommendationsServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("en", forKey: "app.language")
        Bundle.setLanguage("en")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "app.language")
        super.tearDown()
    }

    private func request(
        sex: BiologicalSex = .female,
        age: Int = 30,
        height: Int = 165,
        weight: Double = 65,
        activity: ActivityLevel = .moderate,
        goal: GoalKind = .lose,
        pace: Double? = 0.5,
        kcal: Int = 1700,
        protein: Int = 130,
        fat: Int = 55,
        carbs: Int = 180,
        fiber: Int = 27,
        water: Int = 2300,
        prefs: [DietaryPreference] = [],
        floor: Bool = false
    ) -> RecommendationsRequest {
        RecommendationsRequest(
            biologicalSex: sex,
            age: age,
            heightCm: height,
            weightKg: weight,
            activityLevel: activity,
            goal: goal,
            paceKgPerWeek: pace,
            dailyCalorieGoalKcal: kcal,
            proteinGoalGrams: protein,
            fatGoalGrams: fat,
            carbsGoalGrams: carbs,
            fiberGoalGrams: fiber,
            waterGoalMl: water,
            dietaryPreferences: prefs,
            hitSafetyFloor: floor
        )
    }

    func testAlwaysReturnsSummary() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request())
        XCTAssertFalse(result.summary.isEmpty)
    }

    func testTipsCappedAtFive() async throws {
        let svc = RuleBasedRecommendationsService()
        // Stack the conditions that add tips.
        let result = try await svc.generate(
            for: request(
                activity: .sedentary,
                goal: .lose,
                prefs: [.vegetarian],
                floor: true
            )
        )
        XCTAssertLessThanOrEqual(result.tips.count, 5)
    }

    func testSafetyFloorAddsWarning() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(floor: true))
        XCTAssertFalse(result.warnings.isEmpty)
        XCTAssertTrue(result.warnings.contains { $0.contains("agresywne") || $0.contains("minimum") })
    }

    func testAggressivePaceAddsWarning() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(pace: 1.0))
        XCTAssertFalse(result.warnings.isEmpty)
    }

    func testGentlePaceHasNoWarning() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(pace: 0.25, floor: false))
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testLoseGoalAddsProteinTipWhenBelowThreshold() async throws {
        let svc = RuleBasedRecommendationsService()
        // 80g / 70kg = ~1.14 g/kg — below 1.2 threshold.
        let result = try await svc.generate(for: request(weight: 70, goal: .lose, protein: 80))
        XCTAssertTrue(result.tips.contains { $0.title.lowercased().contains("protein") })
    }

    func testGainGoalAddsCaloricBoostTip() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(goal: .gain))
        XCTAssertTrue(
            result.tips.contains { tip in
                let combined = (tip.title + " " + tip.description).lowercased()
                return combined.contains("calorie") || combined.contains("kcal")
            })
    }

    func testSedentaryAddsWalkingTip() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(activity: .sedentary, prefs: []))
        XCTAssertTrue(result.tips.contains { $0.title.lowercased().contains("walk") })
    }

    func testDietaryPreferenceMentioned() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request(prefs: [.vegan, .glutenFree]))
        // Globalised tip copy now references the Quick Database in English.
        XCTAssertTrue(
            result.tips.contains { tip in
                let combined = (tip.title + " " + tip.description).lowercased()
                return combined.contains("quick database")
                    || combined.contains("vegan")
                    || combined.contains("gluten")
            })
    }

    func testNextStepsNonEmpty() async throws {
        let svc = RuleBasedRecommendationsService()
        for goal in GoalKind.allCases {
            let result = try await svc.generate(for: request(goal: goal))
            XCTAssertFalse(result.nextSteps.isEmpty, "Next steps empty for \(goal)")
        }
    }

    func testSourceIsRuleBased() async throws {
        let svc = RuleBasedRecommendationsService()
        let result = try await svc.generate(for: request())
        XCTAssertEqual(result.source, "rule_based")
    }
}

final class RecommendationsServiceCompositeTests: XCTestCase {
    private struct ThrowingPrimary: RecommendationsServing {
        func generate(for request: RecommendationsRequest) async throws -> Recommendations {
            throw URLError(.notConnectedToInternet)
        }
    }

    private struct StaticFallback: RecommendationsServing {
        let response: Recommendations
        func generate(for request: RecommendationsRequest) async throws -> Recommendations {
            response
        }
    }

    func testNilPrimaryUsesFallback() async throws {
        let fallback = StaticFallback(
            response: Recommendations(
                summary: "test", tips: [], warnings: [], nextSteps: "ok", source: "fallback"
            )
        )
        let svc = RecommendationsService(primary: nil, fallback: fallback)
        let result = try await svc.generate(
            for: RecommendationsRequest(
                biologicalSex: .female, age: 30, heightCm: 165, weightKg: 65,
                activityLevel: .moderate, goal: .maintain, paceKgPerWeek: nil,
                dailyCalorieGoalKcal: 2000, proteinGoalGrams: 100, fatGoalGrams: 60,
                carbsGoalGrams: 200, fiberGoalGrams: 30, waterGoalMl: 2500,
                dietaryPreferences: [], hitSafetyFloor: false
            )
        )
        XCTAssertEqual(result.source, "fallback")
    }

    func testFailingPrimaryFallsBack() async throws {
        let fallback = StaticFallback(
            response: Recommendations(
                summary: "fallback worked", tips: [], warnings: [], nextSteps: "ok", source: "fallback"
            )
        )
        let svc = RecommendationsService(primary: ThrowingPrimary(), fallback: fallback)
        let result = try await svc.generate(
            for: RecommendationsRequest(
                biologicalSex: .female, age: 30, heightCm: 165, weightKg: 65,
                activityLevel: .moderate, goal: .maintain, paceKgPerWeek: nil,
                dailyCalorieGoalKcal: 2000, proteinGoalGrams: 100, fatGoalGrams: 60,
                carbsGoalGrams: 200, fiberGoalGrams: 30, waterGoalMl: 2500,
                dietaryPreferences: [], hitSafetyFloor: false
            )
        )
        XCTAssertEqual(result.summary, "fallback worked")
    }
}
