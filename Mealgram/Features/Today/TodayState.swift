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
    private let culturalDismissals: CulturalEventDismissalStore
    private let coachService: CoachService?
    private let waterService: WaterService?
    private let watchBridge: WatchSessionBridge?
    private let liveActivityService: LiveActivityService?
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        streakService: StreakService,
        recipeRepository: RecipeRepository? = nil,
        culturalEvents: CulturalEventService = CulturalEventService(),
        culturalDismissals: CulturalEventDismissalStore = CulturalEventDismissalStore(),
        coachService: CoachService? = nil,
        waterService: WaterService? = nil,
        watchBridge: WatchSessionBridge? = nil,
        liveActivityService: LiveActivityService? = nil,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.streakService = streakService
        self.recipeRepository = recipeRepository
        self.culturalEvents = culturalEvents
        self.culturalDismissals = culturalDismissals
        self.coachService = coachService
        self.waterService = waterService
        self.watchBridge = watchBridge
        self.liveActivityService = liveActivityService
        self.calendar = calendar
        self.now = now
        self.viewingDate = calendar.startOfDay(for: now())
    }

    func dismissCulturalEvent() {
        guard let upcoming = upcomingEvent else { return }
        culturalDismissals.dismiss(upcoming)
        upcomingEvent = nil
    }

    var isViewingToday: Bool {
        calendar.isDate(viewingDate, inSameDayAs: now())
    }

    /// Moves the visible day back by one. Always allowed.
    func goToPreviousDay(userRemoteID: String) async {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: viewingDate) else { return }
        setViewingDate(previous)
        await refresh(for: userRemoteID)
    }

    /// Moves the visible day forward by one — clamped at today (the
    /// future is empty by definition).
    func goToNextDay(userRemoteID: String) async {
        let today = calendar.startOfDay(for: now())
        guard viewingDate < today else { return }
        guard let next = calendar.date(byAdding: .day, value: 1, to: viewingDate) else { return }
        setViewingDate(min(today, calendar.startOfDay(for: next)))
        await refresh(for: userRemoteID)
    }

    func jumpToToday(userRemoteID: String) async {
        setViewingDate(now())
        await refresh(for: userRemoteID)
    }

    /// Jumps to an arbitrary calendar day chosen via the date picker.
    /// Clamped at today so the user can't scrub into the future.
    func jumpToDate(_ date: Date, userRemoteID: String) async {
        let today = calendar.startOfDay(for: now())
        let dayStart = calendar.startOfDay(for: date)
        setViewingDate(min(today, dayStart))
        await refresh(for: userRemoteID)
    }

    @discardableResult
    func overrideCalorieGoal(_ kcal: Int, userRemoteID: String) async -> Bool {
        do {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.remoteID == userRemoteID }
            )
            guard let user = try context.fetch(descriptor).first else { return false }
            user.dailyCalorieGoalKcal = max(1000, min(4500, kcal))
            user.caloriesOverridden = true
            user.updatedAt = Date()
            regenerateRecommendations(for: user)
            try context.save()
            await refresh(for: userRemoteID)
            return true
        } catch {
            Logger.persistence.error("Calorie goal update failed: \(String(describing: error))")
            loadError = String(describing: error)
            return false
        }
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

            let mealSnapshot = try fetchMealSnapshot(in: context)
            let streak = try streakService.currentStreak(for: userRemoteID)
            let suggestedRecipe = (try? recipeRepository?.all(sortedByCookCount: true))?
                .first { $0.cookCount > 0 }
            let nextEvent = culturalEvents.upcoming(from: now())
            let upcomingEvent = nextEvent.flatMap { event in
                culturalDismissals.isDismissed(event) ? nil : event
            }
            let coachInsights: [CoachInsight]
            if let coachService {
                coachInsights = await coachService.insights(for: userRemoteID)
            } else {
                coachInsights = []
            }
            let waterTotalMl = waterService?.totalToday(for: userRemoteID) ?? 0

            let result = RefreshResult(
                meals: mealSnapshot.meals,
                totals: mealSnapshot.totals,
                streak: streak,
                suggestedRecipe: suggestedRecipe,
                upcomingEvent: upcomingEvent,
                coachInsights: coachInsights,
                waterTotalMl: waterTotalMl
            )
            applyRefreshResult(result)
            // Widget snapshot is "today" only — never publish a stale
            // historical day to the home-screen widget or Watch face.
            if isViewingToday {
                publishWidgetSnapshot()
                publishWatchSnapshot()
                publishLiveActivityUpdate()
            }
        } catch {
            Logger.persistence.error("Today refresh failed: \(String(describing: error))")
            self.loadError = String(describing: error)
        }
    }

    private func fetchMealSnapshot(in context: ModelContext) throws -> MealSnapshot {
        let dayStart = calendar.startOfDay(for: viewingDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return MealSnapshot(meals: [], totals: Totals())
        }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd },
            sortBy: [SortDescriptor(\MealEntry.consumedAt, order: .reverse)]
        )
        let meals = try context.fetch(descriptor)
        let totals = meals.reduce(into: Totals()) { acc, entry in
            acc.calories += entry.totalCaloriesKcal
            acc.protein += entry.totalProteinGrams
            acc.carbs += entry.totalCarbsGrams
            acc.fat += entry.totalFatGrams
        }
        return MealSnapshot(meals: meals, totals: totals)
    }

    private func setViewingDate(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        withAnimation(Tokens.Motion.gentle) {
            viewingDate = dayStart
        }
    }

    private struct MealSnapshot {
        let meals: [MealEntry]
        let totals: Totals
    }

    private struct RefreshResult {
        let meals: [MealEntry]
        let totals: Totals
        let streak: Streak
        let suggestedRecipe: Recipe?
        let upcomingEvent: CulturalEventService.Upcoming?
        let coachInsights: [CoachInsight]
        let waterTotalMl: Int
    }

    private func applyRefreshResult(_ result: RefreshResult) {
        withAnimation(Tokens.Motion.gentle) {
            self.meals = result.meals
            self.totals = result.totals
            self.streak = result.streak
            self.suggestedRecipe = result.suggestedRecipe
            self.upcomingEvent = result.upcomingEvent
            self.coachInsights = result.coachInsights
            self.waterTotalMl = result.waterTotalMl
            self.loadError = nil
        }
    }

    private func regenerateRecommendations(for user: User) {
        guard let recommendations = RuleBasedRecommendationsService.buildSync(for: user) else { return }
        user.latestRecommendationsJSON = try? JSONEncoder().encode(recommendations)
        user.recommendationsGeneratedAt = Date()
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
            if isViewingToday {
                publishWidgetSnapshot()
                publishWatchSnapshot()
                publishLiveActivityUpdate()
            }
        }
        return logged
    }

    @discardableResult
    func undoLastWater(for userRemoteID: String) async -> Bool {
        guard let waterService else { return false }
        let undone = (try? waterService.undoLast(for: userRemoteID)) != nil
        if undone {
            waterTotalMl = waterService.totalToday(for: userRemoteID)
            if isViewingToday {
                publishWidgetSnapshot()
                publishWatchSnapshot()
                publishLiveActivityUpdate()
            }
        }
        return undone
    }

    private func publishWidgetSnapshot() {
        let lastMealName = meals.first?.items.first?.name ?? ""
        // Up to 6 most-recent meals — `meals` is already sorted by
        // `consumedAt` descending. Prefer the meal's "primary" name
        // (first item) and round kcal to the nearest integer so the
        // widget can format without re-rounding.
        let recentMeals: [WidgetSnapshot.MealRow] = meals.prefix(6).map { entry in
            WidgetSnapshot.MealRow(
                name: entry.items.first?.name ?? L("Posiłek"),
                kcal: Int(entry.totalCaloriesKcal.rounded())
            )
        }
        let snapshot = WidgetSnapshot(
            streakLength: streak?.currentLength ?? 0,
            calorieGoalKcal: calorieGoal,
            caloriesConsumedKcal: Int(totals.calories),
            lastMealName: lastMealName,
            updatedAt: now(),
            proteinConsumedGrams: Int(totals.protein.rounded()),
            proteinGoalGrams: user?.proteinGoalGrams ?? 0,
            carbsConsumedGrams: Int(totals.carbs.rounded()),
            carbsGoalGrams: user?.carbsGoalGrams ?? 0,
            fatConsumedGrams: Int(totals.fat.rounded()),
            fatGoalGrams: user?.fatGoalGrams ?? 0,
            waterMl: waterTotalMl,
            waterGoalMl: user?.waterGoalMl ?? 0,
            recentMeals: recentMeals
        )
        WidgetSnapshotStore.shared.write(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Builds the latest Live Activity content state and either starts
    /// the activity (first time today) or updates the running one. Same
    /// data shape as the widget snapshot — calorie + macros + water.
    /// Runs only when viewing today (gated by callers) AND when the
    /// user has at least one meal logged or some water — keeps the
    /// Lock Screen clean for users who haven't engaged yet.
    private func publishLiveActivityUpdate() {
        guard let liveActivityService else { return }
        let hasActivityToShow = !meals.isEmpty || waterTotalMl > 0
        let state = MealgramActivityAttributes.ContentState(
            kcalConsumed: Int(totals.calories.rounded()),
            kcalGoal: calorieGoal,
            proteinConsumed: Int(totals.protein.rounded()),
            proteinGoal: user?.proteinGoalGrams ?? 0,
            carbsConsumed: Int(totals.carbs.rounded()),
            carbsGoal: user?.carbsGoalGrams ?? 0,
            fatConsumed: Int(totals.fat.rounded()),
            fatGoal: user?.fatGoalGrams ?? 0,
            waterMl: waterTotalMl,
            waterGoalMl: user?.waterGoalMl ?? 0,
            updatedAt: now()
        )
        if hasActivityToShow {
            // start() is idempotent — second call within the same day
            // just routes to update() under the hood.
            if liveActivityService.start(initialState: state) == false {
                liveActivityService.update(state: state)
            }
        } else {
            liveActivityService.update(state: state)
        }
    }

    /// Mirrors `publishWidgetSnapshot` but for the Apple Watch
    /// companion. Sent as application context — "current state,
    /// replace previous" — which is the right WCSession primitive
    /// for a small idempotent payload.
    private func publishWatchSnapshot() {
        guard let watchBridge else { return }
        let snapshot = WatchSnapshot(
            kcalConsumed: Int(totals.calories.rounded()),
            kcalGoal: calorieGoal,
            proteinConsumed: Int(totals.protein.rounded()),
            proteinGoal: user?.proteinGoalGrams ?? 0,
            waterMl: waterTotalMl,
            waterGoalMl: user?.waterGoalMl ?? 0,
            updatedAt: now()
        )
        watchBridge.publish(snapshot)
    }

    var greeting: LocalizedStringKey {
        let hour = calendar.component(.hour, from: now())
        switch hour {
        case 5..<11: return "Good morning"
        case 11..<18: return "Hi"
        case 18..<23: return "Good evening"
        default: return "Hej"
        }
    }

    /// True when the user can use a freeze today: there's a streak to
    /// protect, freezes left, and nothing has been logged today yet.
    var canUseFreeze: Bool {
        guard isViewingToday else { return false }
        return StreakFreezePolicy(calendar: calendar).canUseFreeze(
            streak: streak,
            now: now(),
            hasLoggedToday: !meals.isEmpty
        )
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
