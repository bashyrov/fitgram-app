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
    private(set) var dailyOlaPlan: DailyOlaPlan?
    private(set) var waterTotalMl: Int = 0
    private(set) var workouts: [WorkoutEntry] = []
    private(set) var workoutCaloriesBurned: Double = 0
    private(set) var workoutCaloriesCountedTowardGoal: Double = 0
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
    private let workoutService: WorkoutService?
    private let calorieOverrideStore: DailyCalorieOverrideStore
    private let macroOverrideStore: DailyMacroOverrideStore
    private let activityCaloriePolicyStore: ActivityCaloriePolicyStore
    private let watchBridge: WatchSessionBridge?
    private let liveActivityService: LiveActivityService?
    private let calendar: Calendar
    private let now: () -> Date
    private var isImportingHealthWorkouts = false
    private var healthWorkoutObserver: HealthKitService?
    private var healthWorkoutObserverStarted = false
    private var healthWorkoutSyncTask: Task<Void, Never>?

    init(
        container: ModelContainer,
        streakService: StreakService,
        recipeRepository: RecipeRepository? = nil,
        culturalEvents: CulturalEventService = CulturalEventService(),
        culturalDismissals: CulturalEventDismissalStore = CulturalEventDismissalStore(),
        coachService: CoachService? = nil,
        waterService: WaterService? = nil,
        workoutService: WorkoutService? = nil,
        calorieOverrideStore: DailyCalorieOverrideStore = DailyCalorieOverrideStore(),
        macroOverrideStore: DailyMacroOverrideStore = DailyMacroOverrideStore(),
        activityCaloriePolicyStore: ActivityCaloriePolicyStore = ActivityCaloriePolicyStore(),
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
        self.workoutService = workoutService
        self.calorieOverrideStore = calorieOverrideStore
        self.macroOverrideStore = macroOverrideStore
        self.activityCaloriePolicyStore = activityCaloriePolicyStore
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

    func resetForSignedOutUser() {
        totals = Totals()
        meals = []
        user = nil
        streak = nil
        suggestedRecipe = nil
        upcomingEvent = nil
        coachInsights = []
        dailyOlaPlan = nil
        waterTotalMl = 0
        workouts = []
        workoutCaloriesBurned = 0
        workoutCaloriesCountedTowardGoal = 0
        isLoading = false
        loadError = nil
        viewingDate = calendar.startOfDay(for: now())
        WidgetSnapshotStore.shared.clear()
        watchBridge?.publish(.placeholder)
        liveActivityService?.end()
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
    func overrideCalorieGoalForVisibleDay(_ kcal: Int, userRemoteID: String) async -> Bool {
        let clamped = max(1000, min(4500, kcal))
        calorieOverrideStore.set(clamped, for: userRemoteID, on: viewingDate)
        await refresh(for: userRemoteID)
        return true
    }

    @discardableResult
    func overrideMacroGoalsForVisibleDay(
        protein: Int,
        carbs: Int,
        fat: Int,
        userRemoteID: String
    ) async -> Bool {
        let goals = DailyMacroGoals(
            protein: max(0, min(400, protein)),
            carbs: max(0, min(700, carbs)),
            fat: max(0, min(250, fat))
        )
        macroOverrideStore.set(goals, for: userRemoteID, on: viewingDate)
        await refresh(for: userRemoteID)
        return true
    }

    func refresh(for userRemoteID: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            await importHealthWorkoutsIfNeeded(for: userRemoteID)
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
            let dailyOlaPlan: DailyOlaPlan?
            if let coachService {
                coachInsights = await coachService.insights(for: userRemoteID)
                dailyOlaPlan = await coachService.dailyPlan(for: userRemoteID)
            } else {
                coachInsights = []
                dailyOlaPlan = nil
            }
            let waterTotalMl = waterService?.totalToday(for: userRemoteID) ?? 0
            let workouts = (try? workoutService?.workouts(for: userRemoteID, on: viewingDate)) ?? []
            let workoutCalories = workouts.reduce(0) { $0 + $1.caloriesBurnedKcal }
            let countedWorkoutCalories =
                workouts
                .filter(\.countsTowardDailyGoal)
                .reduce(0) { $0 + $1.caloriesBurnedKcal }

            let result = RefreshResult(
                meals: mealSnapshot.meals,
                totals: mealSnapshot.totals,
                streak: streak,
                suggestedRecipe: suggestedRecipe,
                upcomingEvent: upcomingEvent,
                coachInsights: coachInsights,
                dailyOlaPlan: dailyOlaPlan,
                waterTotalMl: waterTotalMl,
                workouts: workouts,
                workoutCaloriesBurned: workoutCalories,
                workoutCaloriesCountedTowardGoal: countedWorkoutCalories
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

    func startHealthWorkoutAutoSync(for userRemoteID: String) async {
        guard workoutService != nil, HealthWorkoutConnectionStore.isEnabled else { return }
        guard !healthWorkoutObserverStarted else { return }

        let health = HealthKitService()
        guard health.isHealthDataAvailable else { return }
        do {
            let granted = try await health.requestAuthorization()
            guard granted else {
                HealthWorkoutConnectionStore.isEnabled = false
                return
            }
            try await health.startWorkoutObserver { [weak self] in
                self?.scheduleHealthWorkoutSync(for: userRemoteID)
            }
            healthWorkoutObserver = health
            healthWorkoutObserverStarted = true
        } catch {
            Logger.persistence.error("Health workout auto-sync setup failed: \(String(describing: error))")
        }
    }

    func syncHealthWorkoutsNow(for userRemoteID: String, force: Bool = false) async {
        guard let workoutService else { return }
        guard force || HealthWorkoutConnectionStore.shouldAutoSync(now: now(), calendar: calendar) else { return }
        guard HealthWorkoutConnectionStore.isEnabled else { return }
        guard !isImportingHealthWorkouts else { return }

        isImportingHealthWorkouts = true
        let result = await HealthWorkoutImporter(
            health: HealthKitService(),
            workoutService: workoutService,
            calendar: calendar
        ).importRecentDays(for: userRemoteID, now: now())
        isImportingHealthWorkouts = false

        switch result {
        case .imported, .noNewSamples:
            HealthWorkoutConnectionStore.markAutoSynced(at: now())
            await refresh(for: userRemoteID)
        case .denied:
            HealthWorkoutConnectionStore.isEnabled = false
        case .unavailable, .failed:
            break
        }
    }

    private func importHealthWorkoutsIfNeeded(for userRemoteID: String) async {
        guard isViewingToday, !isImportingHealthWorkouts else { return }
        guard let workoutService, HealthWorkoutConnectionStore.shouldAutoSync(now: now(), calendar: calendar) else {
            return
        }
        isImportingHealthWorkouts = true
        defer { isImportingHealthWorkouts = false }
        let result = await HealthWorkoutImporter(
            health: HealthKitService(),
            workoutService: workoutService,
            calendar: calendar
        ).importToday(for: userRemoteID, now: now())
        switch result {
        case .imported, .noNewSamples:
            HealthWorkoutConnectionStore.markAutoSynced(at: now())
        case .denied:
            HealthWorkoutConnectionStore.isEnabled = false
        case .unavailable, .failed:
            break
        }
    }

    private func scheduleHealthWorkoutSync(for userRemoteID: String) {
        healthWorkoutSyncTask?.cancel()
        healthWorkoutSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncHealthWorkoutsNow(for: userRemoteID, force: true)
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
        let dailyOlaPlan: DailyOlaPlan?
        let waterTotalMl: Int
        let workouts: [WorkoutEntry]
        let workoutCaloriesBurned: Double
        let workoutCaloriesCountedTowardGoal: Double
    }

    private func applyRefreshResult(_ result: RefreshResult) {
        withAnimation(Tokens.Motion.gentle) {
            self.meals = result.meals
            self.totals = result.totals
            self.streak = result.streak
            self.suggestedRecipe = result.suggestedRecipe
            self.upcomingEvent = result.upcomingEvent
            self.coachInsights = result.coachInsights
            self.dailyOlaPlan = result.dailyOlaPlan
            self.waterTotalMl = result.waterTotalMl
            self.workouts = result.workouts
            self.workoutCaloriesBurned = result.workoutCaloriesBurned
            self.workoutCaloriesCountedTowardGoal = result.workoutCaloriesCountedTowardGoal
            self.loadError = nil
        }
    }

    func applyWorkoutSaved(_ workout: WorkoutEntry) {
        guard calendar.isDate(workout.recordedAt, inSameDayAs: viewingDate) else { return }
        withAnimation(Tokens.Motion.gentle) {
            workouts.insert(workout, at: 0)
            workouts.sort { $0.recordedAt > $1.recordedAt }
            workoutCaloriesBurned += workout.caloriesBurnedKcal
            if workout.countsTowardDailyGoal {
                workoutCaloriesCountedTowardGoal += workout.caloriesBurnedKcal
            }
        }
        if isViewingToday {
            publishWidgetSnapshot()
            publishWatchSnapshot()
            publishLiveActivityUpdate()
        }
    }

    func applyWorkoutSaved(_ workout: WorkoutEntry, userRemoteID: String) {
        applyWorkoutSaved(workout)
        guard isViewingToday else { return }
        Task { await refreshCoachAfterUserAction(for: userRemoteID) }
    }

    @discardableResult
    func deleteWorkout(_ workout: WorkoutEntry, userRemoteID: String) async -> Bool {
        guard let workoutService else { return false }
        do {
            try workoutService.deleteWorkout(id: workout.id, userRemoteID: userRemoteID)
            withAnimation(Tokens.Motion.gentle) {
                workouts.removeAll { $0.id == workout.id }
                workoutCaloriesBurned = max(0, workoutCaloriesBurned - workout.caloriesBurnedKcal)
                if workout.countsTowardDailyGoal {
                    workoutCaloriesCountedTowardGoal = max(
                        0,
                        workoutCaloriesCountedTowardGoal - workout.caloriesBurnedKcal
                    )
                }
            }
            if isViewingToday {
                publishWidgetSnapshot()
                publishWatchSnapshot()
                publishLiveActivityUpdate()
                await refreshCoachAfterUserAction(for: userRemoteID)
            }
            return true
        } catch {
            Logger.persistence.error("Workout delete failed: \(String(describing: error))")
            loadError = String(describing: error)
            return false
        }
    }

    @discardableResult
    func setWorkoutCountsTowardGoal(
        _ workout: WorkoutEntry,
        userRemoteID: String,
        isEnabled: Bool
    ) async -> WorkoutEntry? {
        guard let workoutService else { return nil }
        do {
            guard
                let updated = try workoutService.setCountsTowardDailyGoal(
                    id: workout.id,
                    userRemoteID: userRemoteID,
                    isEnabled: isEnabled
                )
            else { return nil }
            withAnimation(Tokens.Motion.gentle) {
                if let index = workouts.firstIndex(where: { $0.id == updated.id }) {
                    workouts[index] = updated
                }
                workoutCaloriesBurned = workouts.reduce(0) { $0 + $1.caloriesBurnedKcal }
                workoutCaloriesCountedTowardGoal =
                    workouts
                    .filter(\.countsTowardDailyGoal)
                    .reduce(0) { $0 + $1.caloriesBurnedKcal }
            }
            if isViewingToday {
                publishWidgetSnapshot()
                publishWatchSnapshot()
                publishLiveActivityUpdate()
                await refreshCoachAfterUserAction(for: userRemoteID)
            }
            return updated
        } catch {
            Logger.persistence.error("Workout goal toggle failed: \(String(describing: error))")
            loadError = String(describing: error)
            return nil
        }
    }

    private func regenerateRecommendations(for user: User) {
        guard let recommendations = RuleBasedRecommendationsService.buildSync(for: user) else { return }
        user.latestRecommendationsJSON = try? JSONEncoder().encode(recommendations)
        user.recommendationsGeneratedAt = Date()
    }

    // MARK: - Derived

    var calorieGoal: Int {
        baseCalorieGoal + Int(workoutCaloriesAppliedToGoal.rounded())
    }

    var baseCalorieGoal: Int {
        guard let user else { return 2100 }
        return calorieOverrideStore.value(for: user.remoteID, on: viewingDate) ?? user.dailyCalorieGoalKcal
    }

    var includesActivityCaloriesInGoal: Bool {
        activityCaloriePolicyStore.includesActivityCalories(on: viewingDate, now: now())
    }

    var workoutCaloriesAppliedToGoal: Double {
        includesActivityCaloriesInGoal ? workoutCaloriesCountedTowardGoal : 0
    }

    var proteinGoal: Int { macroGoals.protein }
    var carbsGoal: Int { macroGoals.carbs }
    var fatGoal: Int { macroGoals.fat }

    private var macroGoals: DailyMacroGoals {
        guard let user else {
            return DailyMacroGoals(protein: 120, carbs: 240, fat: 70)
        }
        if let override = macroOverrideStore.value(for: user.remoteID, on: viewingDate) {
            return override
        }
        if user.macrosOverridden {
            let base = max(1, baseCalorieGoal)
            let ratio = max(0.25, min(2.5, Double(calorieGoal) / Double(base)))
            return DailyMacroGoals(
                protein: Int((Double(user.proteinGoalGrams) * ratio).rounded()),
                carbs: Int((Double(user.carbsGoalGrams) * ratio).rounded()),
                fat: Int((Double(user.fatGoalGrams) * ratio).rounded())
            )
        }
        let split = GoalCalculator.macroSplit(for: user.goalKind, preset: user.dietMacroPreset)
        let calories = Double(max(0, calorieGoal))
        return DailyMacroGoals(
            protein: Int(((calories * split.protein) / 4).rounded()),
            carbs: Int(((calories * split.carbs) / 4).rounded()),
            fat: Int(((calories * split.fat) / 9).rounded())
        )
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
                await refreshCoachAfterUserAction(for: userRemoteID)
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
                await refreshCoachAfterUserAction(for: userRemoteID)
            }
        }
        return undone
    }

    private func refreshCoachAfterUserAction(for userRemoteID: String) async {
        guard isViewingToday, let coachService else { return }
        let insights = await coachService.insights(for: userRemoteID)
        let plan = await coachService.dailyPlan(for: userRemoteID)
        withAnimation(Tokens.Motion.gentle) {
            coachInsights = insights
            dailyOlaPlan = plan
        }
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
            proteinGoalGrams: proteinGoal,
            carbsConsumedGrams: Int(totals.carbs.rounded()),
            carbsGoalGrams: carbsGoal,
            fatConsumedGrams: Int(totals.fat.rounded()),
            fatGoalGrams: fatGoal,
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
        let state = FitgramActivityAttributes.ContentState(
            kcalConsumed: Int(totals.calories.rounded()),
            kcalGoal: calorieGoal,
            proteinConsumed: Int(totals.protein.rounded()),
            proteinGoal: proteinGoal,
            carbsConsumed: Int(totals.carbs.rounded()),
            carbsGoal: carbsGoal,
            fatConsumed: Int(totals.fat.rounded()),
            fatGoal: fatGoal,
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
            proteinGoal: proteinGoal,
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

struct DailyCalorieOverrideStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func value(for userRemoteID: String, on date: Date) -> Int? {
        let value = defaults.integer(forKey: key(userRemoteID: userRemoteID, date: date))
        return value > 0 ? value : nil
    }

    func set(_ kcal: Int, for userRemoteID: String, on date: Date) {
        defaults.set(max(1000, min(4500, kcal)), forKey: key(userRemoteID: userRemoteID, date: date))
    }

    private func key(userRemoteID: String, date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return
            "dailyCalorieOverride.\(userRemoteID).\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

struct DailyMacroGoals: Codable, Equatable, Sendable {
    var protein: Int
    var carbs: Int
    var fat: Int
}

struct DailyMacroOverrideStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func value(for userRemoteID: String, on date: Date) -> DailyMacroGoals? {
        guard let data = defaults.data(forKey: key(userRemoteID: userRemoteID, date: date)) else { return nil }
        return try? JSONDecoder().decode(DailyMacroGoals.self, from: data)
    }

    func set(_ goals: DailyMacroGoals, for userRemoteID: String, on date: Date) {
        guard let data = try? JSONEncoder().encode(goals) else { return }
        defaults.set(data, forKey: key(userRemoteID: userRemoteID, date: date))
    }

    private func key(userRemoteID: String, date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "dailyMacroOverride.%@.%04d-%02d-%02d",
            userRemoteID,
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

struct ActivityCaloriePolicyStore {
    static let currentKey = "fitgram.activityCalories.includeInDailyGoal.current"
    static let changedNotification = Notification.Name("FitgramActivityCaloriePolicyChanged")
    static let defaultIncludesActivityCalories = true

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    var currentValue: Bool {
        if defaults.object(forKey: Self.currentKey) == nil {
            return Self.defaultIncludesActivityCalories
        }
        return defaults.bool(forKey: Self.currentKey)
    }

    func includesActivityCalories(on date: Date, now: Date = Date()) -> Bool {
        let key = dayKey(for: date)
        if defaults.object(forKey: key) != nil {
            return defaults.bool(forKey: key)
        }
        if calendar.isDate(date, inSameDayAs: now) {
            return currentValue
        }
        if date < calendar.startOfDay(for: now) {
            return Self.defaultIncludesActivityCalories
        }
        return currentValue
    }

    func setCurrent(_ isIncluded: Bool, now: Date = Date()) {
        defaults.set(isIncluded, forKey: Self.currentKey)
        defaults.set(isIncluded, forKey: dayKey(for: now))
        NotificationCenter.default.post(name: Self.changedNotification, object: nil)
    }

    private func dayKey(for date: Date) -> String {
        let day = calendar.startOfDay(for: date)
        let components = calendar.dateComponents([.year, .month, .day], from: day)
        return String(
            format: "fitgram.activityCalories.includeInDailyGoal.%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}
