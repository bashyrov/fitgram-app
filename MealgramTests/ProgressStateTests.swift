import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class ProgressStateTests: XCTestCase {
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

    /// Calendar pinned to UTC so the ISO test dates round-trip without
    /// system-timezone wobble.
    private static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    func testBucketProducesSevenDaysWithZeroCalorieFillers() {
        let today = Self.date("2026-05-12T00:00:00Z")
        let weekStart = Self.date("2026-05-06T00:00:00Z")
        let buckets = ProgressState.bucket(
            entries: [],
            weekStart: weekStart,
            today: today,
            calendar: Self.utcCalendar
        )
        XCTAssertEqual(buckets.count, 7)
        XCTAssertTrue(buckets.allSatisfy { $0.calories == 0 && $0.mealCount == 0 })
    }

    func testBucketingAggregatesEntriesByDay() throws {
        let calendar = Self.utcCalendar
        let mondayMorning = Self.date("2026-05-11T08:00:00Z")
        let mondayEvening = Self.date("2026-05-11T19:00:00Z")
        let tuesday = Self.date("2026-05-12T12:00:00Z")

        let meals = [
            MealEntry(
                consumedAt: mondayMorning,
                mealType: .breakfast,
                source: .quickDatabase,
                items: [FoodItem(name: "Owsianka", quantityGrams: 200, caloriesKcal: 200, proteinGrams: 5)]
            ),
            MealEntry(
                consumedAt: mondayEvening,
                mealType: .dinner,
                source: .photoScan,
                items: [FoodItem(name: "Schabowy", quantityGrams: 180, caloriesKcal: 400, proteinGrams: 30)]
            ),
            MealEntry(
                consumedAt: tuesday,
                mealType: .lunch,
                source: .photoScan,
                items: [FoodItem(name: "Kurczak", quantityGrams: 150, caloriesKcal: 250, proteinGrams: 40)]
            ),
        ]

        let weekStart = Self.date("2026-05-06T00:00:00Z")
        let buckets = ProgressState.bucket(
            entries: meals,
            weekStart: weekStart,
            today: Self.date("2026-05-12T00:00:00Z"),
            calendar: calendar
        )
        let monday = try XCTUnwrap(buckets.first { calendar.isDate($0.date, inSameDayAs: mondayMorning) })
        let tuesdayBucket = try XCTUnwrap(buckets.first { calendar.isDate($0.date, inSameDayAs: tuesday) })
        XCTAssertEqual(monday.mealCount, 2)
        XCTAssertEqual(monday.calories, 600, accuracy: 0.001)
        XCTAssertEqual(tuesdayBucket.mealCount, 1)
        XCTAssertEqual(tuesdayBucket.calories, 250, accuracy: 0.001)
    }

    func testRefreshReadsUserGoalAndAggregates() async throws {
        let now = Self.date("2026-05-12T18:00:00Z")
        let user = User(remoteID: "u-pp")
        user.dailyCalorieGoalKcal = 1800
        context.insert(user)
        let entry = MealEntry(
            consumedAt: Self.date("2026-05-12T12:00:00Z"),
            mealType: .lunch,
            source: .photoScan,
            items: [FoodItem(name: "X", quantityGrams: 100, caloriesKcal: 100)]
        )
        context.insert(entry)
        try context.save()

        let state = ProgressState(
            container: controller.container,
            calendar: Self.utcCalendar,
            now: { now }
        )
        await state.refresh(for: "u-pp")
        XCTAssertEqual(state.goalKcal, 1800)
        XCTAssertEqual(state.lastSevenDays.count, 7)
        XCTAssertEqual(state.totalKcalThisWeek, 100, accuracy: 0.001)
        let bestDay = try XCTUnwrap(state.bestDay)
        XCTAssertEqual(bestDay.calories, 100, accuracy: 0.001)
        XCTAssertEqual(state.averageCalories, 100, accuracy: 0.001)
    }
}
