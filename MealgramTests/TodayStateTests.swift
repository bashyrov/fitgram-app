import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class TodayStateTests: XCTestCase {
    private var controller: PersistenceController!
    private var context: ModelContext!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        context = ModelContext(controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        context = nil
    }

    private static func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: iso) else { fatalError("Bad ISO date \(iso)") }
        return date
    }

    func testEmptyStoreReturnsZeroTotals() async throws {
        let now = Self.date("2026-05-12T12:00:00Z")
        let service = StreakService(container: controller.container, now: { now })
        let state = TodayState(container: controller.container, streakService: service, now: { now })

        await state.refresh(for: "u-1")
        XCTAssertEqual(state.totals.calories, 0)
        XCTAssertTrue(state.meals.isEmpty)
    }

    func testTodaysMealsAreSummedAndYesterdayIgnored() async throws {
        // Use a midday "now" so we have plenty of buffer at both ends.
        let now = Self.date("2026-05-12T18:00:00Z")
        let yesterday = Self.date("2026-05-11T12:00:00Z")
        let todayMorning = Self.date("2026-05-12T09:00:00Z")
        let todayLunch = Self.date("2026-05-12T13:30:00Z")

        let oldMeal = MealEntry(
            consumedAt: yesterday,
            mealType: .lunch,
            source: .manual,
            items: [
                FoodItem(
                    name: "Old", quantityGrams: 100, caloriesKcal: 999, proteinGrams: 0, carbsGrams: 0, fatGrams: 0)
            ]
        )
        let m1 = MealEntry(
            consumedAt: todayMorning,
            mealType: .breakfast,
            source: .quickDatabase,
            items: [
                FoodItem(
                    name: "Owsianka", quantityGrams: 200, caloriesKcal: 320, proteinGrams: 10, carbsGrams: 60,
                    fatGrams: 6)
            ]
        )
        let m2 = MealEntry(
            consumedAt: todayLunch,
            mealType: .lunch,
            source: .photoScan,
            portionMultiplier: 1.5,
            items: [
                FoodItem(
                    name: "Kurczak", quantityGrams: 150, caloriesKcal: 250, proteinGrams: 40, carbsGrams: 0, fatGrams: 8
                )
            ]
        )
        context.insert(oldMeal)
        context.insert(m1)
        context.insert(m2)
        try context.save()

        let service = StreakService(container: controller.container, now: { now })
        let state = TodayState(container: controller.container, streakService: service, now: { now })

        await state.refresh(for: "u-1")
        XCTAssertEqual(state.meals.count, 2)
        XCTAssertEqual(state.totals.calories, 320 + 250 * 1.5, accuracy: 0.001)
        XCTAssertEqual(state.totals.protein, 10 + 40 * 1.5, accuracy: 0.001)
        XCTAssertEqual(state.totals.carbs, 60, accuracy: 0.001)
        XCTAssertEqual(state.totals.fat, 6 + 8 * 1.5, accuracy: 0.001)
    }

    func testCalorieGoalDefaultsApply() async throws {
        let now = Self.date("2026-05-12T12:00:00Z")
        let service = StreakService(container: controller.container, now: { now })
        let state = TodayState(container: controller.container, streakService: service, now: { now })

        await state.refresh(for: "u-missing")
        XCTAssertEqual(state.calorieGoal, 2100)
        XCTAssertEqual(state.calorieRemaining, 2100)
    }

    func testGreetingByHour() async throws {
        for (hour, expected) in [
            (8, "Dzień dobry"),
            (13, "Cześć"),
            (20, "Dobry wieczór"),
            (2, "Hej"),
        ] {
            let fixed = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
            let service = StreakService(container: controller.container, now: { fixed })
            let state = TodayState(container: controller.container, streakService: service, now: { fixed })
            // Trigger reading greeting once — refresh isn't required for that derived property.
            let greeting = state.greeting
            // Hash via inspection isn't trivial; assert with descriptor instead.
            let mirror = String(describing: greeting)
            XCTAssertTrue(mirror.contains(expected), "Hour \(hour) expected to include \(expected), got \(mirror)")
        }
    }
}
