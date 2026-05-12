import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class AchievementEngineTests: XCTestCase {
    private let engine = AchievementEngine(calendar: Calendar(identifier: .gregorian))

    private func meal(
        at iso: String,
        mealType: MealType = .lunch,
        source: MealSource = .manual,
        items: [FoodItem] = [FoodItem(name: "X", quantityGrams: 100, caloriesKcal: 50)]
    ) -> MealEntry {
        let date = Self.date(iso)
        return MealEntry(
            consumedAt: date,
            mealType: mealType,
            source: source,
            items: items
        )
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
        return date
    }

    func testEmptyInputsUnlockNothing() {
        let unlocks = engine.evaluate(meals: [], streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.isEmpty)
    }

    func testFirstMealUnlocksMealAndSourceSpecific() {
        let meals = [meal(at: "2026-05-12T12:00:00Z", source: .photoScan)]
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("meal.first"))
        XCTAssertTrue(unlocks.contains("scan.first"))
        XCTAssertFalse(unlocks.contains("barcode.first"))
    }

    func testBarcodeFirstFires() {
        let meals = [meal(at: "2026-05-12T12:00:00Z", source: .barcode)]
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("barcode.first"))
    }

    func testStreakMilestonesGateOnLongestLength() {
        let meals = [meal(at: "2026-05-12T12:00:00Z")]
        let weak = Streak(userRemoteID: "u", currentLength: 1, longestLength: 6)
        XCTAssertFalse(engine.evaluate(meals: meals, streak: weak, alreadyEarned: []).contains("streak.7"))

        let seven = Streak(userRemoteID: "u", currentLength: 1, longestLength: 7)
        XCTAssertTrue(engine.evaluate(meals: meals, streak: seven, alreadyEarned: []).contains("streak.7"))
        XCTAssertFalse(engine.evaluate(meals: meals, streak: seven, alreadyEarned: []).contains("streak.30"))

        let thirty = Streak(userRemoteID: "u", currentLength: 30, longestLength: 30)
        let unlocks = engine.evaluate(meals: meals, streak: thirty, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("streak.7"))
        XCTAssertTrue(unlocks.contains("streak.30"))
        XCTAssertFalse(unlocks.contains("streak.100"))
    }

    func testProteinHeavyTriggersOnAnyOneDay() {
        // 80 g + 50 g on the same day → 130 g, above 120 g threshold.
        let meals = [
            meal(
                at: "2026-05-12T09:00:00Z",
                items: [FoodItem(name: "A", quantityGrams: 200, caloriesKcal: 400, proteinGrams: 80)]
            ),
            meal(
                at: "2026-05-12T19:00:00Z",
                items: [FoodItem(name: "B", quantityGrams: 150, caloriesKcal: 250, proteinGrams: 50)]
            ),
        ]
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertTrue(unlocks.contains("protein.heavy"))
    }

    func testProteinHeavyDoesNotTriggerAcrossDays() {
        let meals = [
            meal(
                at: "2026-05-12T19:00:00Z",
                items: [FoodItem(name: "A", quantityGrams: 200, caloriesKcal: 400, proteinGrams: 80)]
            ),
            meal(
                at: "2026-05-13T09:00:00Z",
                items: [FoodItem(name: "B", quantityGrams: 150, caloriesKcal: 250, proteinGrams: 50)]
            ),
        ]
        let unlocks = engine.evaluate(meals: meals, streak: nil, alreadyEarned: [])
        XCTAssertFalse(unlocks.contains("protein.heavy"))
    }

    func testVarietyDayRequiresThreeMealTypes() {
        let day = [
            meal(at: "2026-05-12T08:00:00Z", mealType: .breakfast),
            meal(at: "2026-05-12T13:00:00Z", mealType: .lunch),
            meal(at: "2026-05-12T19:00:00Z", mealType: .dinner),
        ]
        XCTAssertTrue(engine.evaluate(meals: day, streak: nil, alreadyEarned: []).contains("variety.day"))

        let missingDinner = Array(day.prefix(2))
        XCTAssertFalse(
            engine.evaluate(meals: missingDinner, streak: nil, alreadyEarned: []).contains("variety.day")
        )
    }

    func testAlreadyEarnedAreSkipped() {
        let meals = [meal(at: "2026-05-12T12:00:00Z", source: .photoScan)]
        let unlocks = engine.evaluate(
            meals: meals,
            streak: nil,
            alreadyEarned: ["meal.first", "scan.first"]
        )
        XCTAssertTrue(unlocks.isEmpty)
    }
}
