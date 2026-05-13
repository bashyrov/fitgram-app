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
    private(set) var waterTotalMl: Int = 0
    private(set) var isLoading = false
    private(set) var loadError: String?

    /// The day currently being shown. Mutated via `goToPreviousDay()` /
    /// `goToNextDay()` / `jumpToToday()`; always start-of-day. Driving
    /// the meal-window fetch off this lets the user scrub history
    /// without leaving the Today tab.
    private(set) var viewingDate: Date = Calendar.current.startOfDay(for: Date())

    private let container: ModelContainer
    private let streakService: StreakService
    private let recipeRepository: RecipeRepository?
    private let culturalEvents: CulturalEventService
    private let coachService: CoachService?
    private let waterService: WaterService?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        streakService: StreakService,
        recipeRepository: RecipeRepository? = nil,
        culturalEvents: CulturalEventService = CulturalEventService(),
        coachService: CoachService? = nil,
        waterService: WaterService? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.recipeRepository = recipeRepository
        self.culturalEvents = culturalEvents
        self.coachService = coachService
        self.waterService = waterService
        self.calendar = calendar
        self.now = now
        self.viewingDate = calendar.startOfDay(for: now())
    }

    var isViewingToday: Bool {
        calendar.isDate(viewingDate, inSameDayAs: now())
    }

    /// Moves the visible day back by one. Always allowed.
    func goToPreviousDay(userRemoteID: String) async {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: viewingDate) else { return }
        viewingDate = calendar.startOfDay(for: previous)
        await refresh(for: userRemoteID)
    }

    /// Moves the visible day forward by one — clamped at today (the
    /// future is empty by definition).
    func goToNextDay(userRemoteID: String) async {
        let today = calendar.startOfDay(for: now())
        guard viewingDate < today else { return }
        guard let next = calendar.date(byAdding: .day, value: 1, to: viewingDate) else { return }
        viewingDate = min(today, calendar.startOfDay(for: next))
        await refresh(for: userRemoteID)
    }

    func jumpToToday(userRemoteID: String) async {
        viewingDate = calendar.startOfDay(for: now())
        await refresh(for: userRemoteID)
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

            let dayStart = calendar.startOfDay(for: viewingDate)
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
            self.waterTotalMl = waterService?.totalToday(for: userRemoteID) ?? 0
            self.loadError = nil
            // Widget snapshot is "today" only — never publish a stale
            // historical day to the home-screen widget.
            if isViewingToday {
                publishWidgetSnapshot()
            }
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
    @discardableResult
    func logWaterGlass(for userRemoteID: String) async -> Bool {
        guard let waterService else { return false }
        let logged =
            (try? waterService.log(
                forUser: userRemoteID, milliliters: WaterService.glassMilliliters
            )) != nil
        if logged {
            waterTotalMl = waterService.totalToday(for: userRemoteID)
        }
        return logged
    }

    @discardableResult
    func undoLastWater(for userRemoteID: String) async -> Bool {
        guard let waterService else { return false }
        let undone = (try? waterService.undoLast(for: userRemoteID)) != nil
        if undone {
            waterTotalMl = waterService.totalToday(for: userRemoteID)
        }
        return undone
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
        guard isViewingToday else { return false }
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
