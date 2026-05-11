import Foundation
import OSLog
import Observation
import SwiftData
import SwiftUI

/// Aggregates today's meal entries + the user's daily target. Refreshes via
/// `refresh()` after sign-in or after a meal save. Pure read model — no
/// mutation goes through here.
@MainActor
@Observable
final class TodayState {
    struct Totals: Equatable, Sendable {
        var calories: Double = 0
        var protein: Double = 0
        var carbs: Double = 0
        var fat: Double = 0
    }

    private(set) var totals = Totals()
    private(set) var meals: [MealEntry] = []
    private(set) var user: User?
    private(set) var streak: Streak?
    private(set) var isLoading = false
    private(set) var loadError: String?

    private let container: ModelContainer
    private let streakService: StreakService
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        streakService: StreakService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.calendar = calendar
        self.now = now
    }

    func refresh(for userRemoteID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let context = ModelContext(container)
            let userDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.remoteID == userRemoteID }
            )
            let user = try context.fetch(userDescriptor).first
            self.user = user

            let dayStart = calendar.startOfDay(for: now())
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                self.meals = []
                self.totals = Totals()
                return
            }
            let mealDescriptor = FetchDescriptor<MealEntry>(
                predicate: #Predicate { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd },
                sortBy: [SortDescriptor(\MealEntry.consumedAt, order: .reverse)]
            )
            let entries = try context.fetch(mealDescriptor)
            self.meals = entries
            self.totals = entries.reduce(into: Totals()) { acc, entry in
                acc.calories += entry.totalCaloriesKcal
                acc.protein += entry.totalProteinGrams
                acc.carbs += entry.totalCarbsGrams
                acc.fat += entry.totalFatGrams
            }
            self.streak = try streakService.currentStreak(for: userRemoteID)
            self.loadError = nil
        } catch {
            Logger.persistence.error("Today refresh failed: \(String(describing: error))")
            self.loadError = String(describing: error)
        }
    }

    // MARK: - Derived

    var calorieGoal: Int {
        user?.dailyCalorieGoalKcal ?? 2100
    }
    var calorieRemaining: Int {
        max(0, calorieGoal - Int(totals.calories))
    }
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1.0, totals.calories / Double(calorieGoal))
    }
    var greeting: LocalizedStringKey {
        let hour = calendar.component(.hour, from: now())
        switch hour {
        case 5..<11: return "Dzień dobry"
        case 11..<18: return "Cześć"
        case 18..<23: return "Dobry wieczór"
        default: return "Hej"
        }
    }
}
