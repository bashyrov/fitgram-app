import Foundation
import OSLog
import Observation
import SwiftData
import SwiftUI
import WidgetKit

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
    private(set) var suggestedRecipe: Recipe?
    private(set) var upcomingEvent: CulturalEventService.Upcoming?
    private(set) var coachInsights: [CoachInsight] = []
    private(set) var isLoading = false
    private(set) var loadError: String?

    private let container: ModelContainer
    private let streakService: StreakService
    private let recipeRepository: RecipeRepository?
    private let culturalEvents: CulturalEventService
    private let coachService: CoachService?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        streakService: StreakService,
        recipeRepository: RecipeRepository? = nil,
        culturalEvents: CulturalEventService = CulturalEventService(),
        coachService: CoachService? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.recipeRepository = recipeRepository
        self.culturalEvents = culturalEvents
        self.coachService = coachService
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
            self.suggestedRecipe = (try? recipeRepository?.all(sortedByCookCount: true))?
                .first { $0.cookCount > 0 }
            self.upcomingEvent = culturalEvents.upcoming(from: now())
            self.coachInsights = coachService?.insights(for: userRemoteID) ?? []
            self.loadError = nil
            publishWidgetSnapshot()
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
    private func publishWidgetSnapshot() {
        let lastMealName = meals.first?.items.first?.name ?? ""
        let snapshot = WidgetSnapshot(
            streakLength: streak?.currentLength ?? 0,
            calorieGoalKcal: calorieGoal,
            caloriesConsumedKcal: Int(totals.calories),
            lastMealName: lastMealName,
            updatedAt: now()
        )
        WidgetSnapshotStore.shared.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
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

    /// True when the user can use a freeze today: there's a streak to
    /// protect, freezes left, and nothing has been logged today yet.
    var canUseFreeze: Bool {
        guard let streak, streak.currentLength > 0, streak.freezesAvailable > 0 else { return false }
        let dayStart = calendar.startOfDay(for: now())
        if let last = streak.lastLoggedDate, calendar.startOfDay(for: last) >= dayStart {
            return false
        }
        return totals.calories == 0
    }

    /// Consumes one freeze and refreshes. Returns true if a freeze was
    /// successfully consumed.
    @discardableResult
    func consumeFreeze(for userRemoteID: String) async -> Bool {
        let consumed = (try? streakService.consumeFreeze(for: userRemoteID)) ?? false
        if consumed {
            await refresh(for: userRemoteID)
        }
        return consumed
    }
}
