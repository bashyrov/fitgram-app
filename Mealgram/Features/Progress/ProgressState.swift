import Foundation
import OSLog
import Observation
import SwiftData

/// Reads the user's last-7-days history for the Progress tab. Groups meals
/// by day, computes per-day totals, exposes the user's daily calorie goal
/// so the chart can render the target line.
@MainActor
@Observable
final class ProgressState {
    struct DayTotal: Identifiable, Equatable, Sendable {
        let date: Date
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let mealCount: Int

        var id: Date { date }
        var caloriesInt: Int { Int(calories) }
    }

    private(set) var lastSevenDays: [DayTotal] = []
    private(set) var goalKcal: Int = 2100
    private(set) var isLoading = false

    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    func refresh(for userRemoteID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let context = ModelContext(container)
            let userFetch = FetchDescriptor<User>(
                predicate: #Predicate { $0.remoteID == userRemoteID }
            )
            if let user = try context.fetch(userFetch).first {
                goalKcal = user.dailyCalorieGoalKcal
            }

            let today = calendar.startOfDay(for: now())
            guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: today) else {
                lastSevenDays = []
                return
            }
            let descriptor = FetchDescriptor<MealEntry>(
                predicate: #Predicate { $0.consumedAt >= weekAgo },
                sortBy: [SortDescriptor(\MealEntry.consumedAt)]
            )
            let entries = try context.fetch(descriptor)
            lastSevenDays = Self.bucket(
                entries: entries,
                weekStart: weekAgo,
                today: today,
                calendar: calendar
            )
        } catch {
            Logger.persistence.error("Progress refresh failed: \(String(describing: error))")
        }
    }

    /// Public for tests — bucketing logic without SwiftData.
    static func bucket(
        entries: [MealEntry],
        weekStart: Date,
        today: Date,
        calendar: Calendar
    ) -> [DayTotal] {
        let grouped = Dictionary(grouping: entries) { calendar.startOfDay(for: $0.consumedAt) }
        return (0...6).compactMap { offset -> DayTotal? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else {
                return nil
            }
            let dayEntries = grouped[day] ?? []
            return DayTotal(
                date: day,
                calories: dayEntries.reduce(0) { $0 + $1.totalCaloriesKcal },
                protein: dayEntries.reduce(0) { $0 + $1.totalProteinGrams },
                carbs: dayEntries.reduce(0) { $0 + $1.totalCarbsGrams },
                fat: dayEntries.reduce(0) { $0 + $1.totalFatGrams },
                mealCount: dayEntries.count
            )
        }
    }

    /// Convenience: average calories across days that actually have entries.
    var averageCalories: Double {
        let active = lastSevenDays.filter { $0.mealCount > 0 }
        guard !active.isEmpty else { return 0 }
        return active.reduce(0) { $0 + $1.calories } / Double(active.count)
    }

    var bestDay: DayTotal? {
        lastSevenDays.max(by: { $0.calories < $1.calories })
    }

    var totalKcalThisWeek: Double {
        lastSevenDays.reduce(0) { $0 + $1.calories }
    }
}
