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
    let calorieOverrideStore: DailyCalorieOverrideStore
    let macroOverrideStore: DailyMacroOverrideStore
    let activityCaloriePolicyStore: ActivityCaloriePolicyStore
    private let watchBridge: WatchSessionBridge?
    private let liveActivityService: LiveActivityService?
    private let calendar: Calendar
    let now: () -> Date
    private let healthSync: TodayHealthWorkoutSync

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
        self.healthSync = TodayHealthWorkoutSync(workoutService: workoutService, calendar: calendar, now: now)
        healthSync.onSynced = { [weak self] userRemoteID in
            await self?.refresh(for: userRemoteID)
        }
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
            if isViewingToday {
                await healthSync.importTodayIfNeeded(for: userRemoteID)
            }
            let context = ModelContext(container)
            let userDescriptor = FetchDescriptor<User>(
                predicate: #Predicate { $0.remoteID == userRemoteID }
            )
            let user = try context.fetch(userDescriptor).first
            self.user = user

            let mealSnapshot = try MealSnapshot.fetch(day: viewingDate, calendar: calendar, in: context)
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
                publishTodaySurfaces()
            }
        } catch {
            Logger.persistence.error("Today refresh failed: \(String(describing: error))")
            self.loadError = String(describing: error)
        }
    }

    func startHealthWorkoutAutoSync(for userRemoteID: String) async {
        await healthSync.startAutoSync(for: userRemoteID)
    }

    func syncHealthWorkoutsNow(for userRemoteID: String, force: Bool = false) async {
        await healthSync.syncNow(for: userRemoteID, force: force)
    }

    private func setViewingDate(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)
        withAnimation(Tokens.Motion.gentle) {
            viewingDate = dayStart
        }
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
}

// MARK: - Workouts
extension TodayState {

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
            publishTodaySurfaces()
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
                publishTodaySurfaces()
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
                publishTodaySurfaces()
                await refreshCoachAfterUserAction(for: userRemoteID)
            }
            return updated
        } catch {
            Logger.persistence.error("Workout goal toggle failed: \(String(describing: error))")
            loadError = String(describing: error)
            return nil
        }
    }
}

// MARK: - Water
extension TodayState {

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
                publishTodaySurfaces()
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
                publishTodaySurfaces()
                await refreshCoachAfterUserAction(for: userRemoteID)
            }
        }
        return undone
    }
}

// MARK: - Coach + outside surfaces
extension TodayState {

    private func refreshCoachAfterUserAction(for userRemoteID: String) async {
        guard isViewingToday, let coachService else { return }
        let insights = await coachService.insights(for: userRemoteID)
        let plan = await coachService.dailyPlan(for: userRemoteID)
        withAnimation(Tokens.Motion.gentle) {
            coachInsights = insights
            dailyOlaPlan = plan
        }
    }

    /// Mirrors today's numbers to the home-screen widget, the Live
    /// Activity and the Watch. Callers only publish while viewing today —
    /// a historical day must never reach those surfaces.
    private func publishTodaySurfaces() {
        let payloads = TodaySurfacePayloads(
            totals: totals,
            goals: .init(calories: calorieGoal, protein: proteinGoal, carbs: carbsGoal, fat: fatGoal),
            waterMl: waterTotalMl,
            waterGoalMl: user?.waterGoalMl ?? 0,
            meals: meals,
            streakLength: streak?.currentLength ?? 0,
            updatedAt: now()
        )
        WidgetSnapshotStore.shared.write(payloads.widget)
        WidgetCenter.shared.reloadAllTimelines()
        watchBridge?.publish(payloads.watch)
        if let liveActivityService {
            // start() is idempotent — a second call within the same day
            // just routes to update() under the hood. Users who haven't
            // logged anything yet keep a clean Lock Screen.
            if !payloads.hasActivityToShow || liveActivityService.start(initialState: payloads.liveActivity) == false {
                liveActivityService.update(state: payloads.liveActivity)
            }
        }
    }
}

// MARK: - Greeting + streak freeze
extension TodayState {

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
