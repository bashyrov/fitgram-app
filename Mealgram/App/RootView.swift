import SwiftUI

/// Top-level routing. Reacts to the shared `AuthSession` via `AppRouter`
/// to show one of: launch splash, auth stack, onboarding, or the main tab
/// scene.
struct RootView: View {
    @Environment(AuthSession.self) private var session
    let authService: AuthService
    let userRepository: UserRepository
    let mealSaver: any MealSaving
    let todayState: TodayState
    let streakService: StreakService
    let accountDeletionService: AccountDeletionService
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
    let mealSearchService: MealSearchService
    let streakCalendarService: StreakCalendarService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let foodCatalog: any FoodCatalog
    let progressState: ProgressState
    let recipeRepository: RecipeRepository
    let mealRepository: MealRepository
    let photoStore: MealPhotoStore?
    let weightService: WeightService
    let heatmapService: ActivityHeatmapService
    let challengeService: ChallengeService
    let statsService: ProfileStatsService
    let friendService: any FriendService
    let coachService: CoachService
    let notificationCoordinator: NotificationCoordinator
    let unlockBus: AchievementUnlockBus

    @State private var router: AppRouter
    @State private var onboardingFlow: OnboardingFlow?

    init(
        authService: AuthService,
        userRepository: UserRepository,
        mealSaver: any MealSaving,
        todayState: TodayState,
        streakService: StreakService,
        accountDeletionService: AccountDeletionService,
        exportService: DataExportService,
        csvExportService: MealCSVExportService,
        mealSearchService: MealSearchService,
        streakCalendarService: StreakCalendarService,
        achievementService: AchievementService,
        calibrationService: CalibrationService,
        foodCatalog: any FoodCatalog,
        progressState: ProgressState,
        recipeRepository: RecipeRepository,
        mealRepository: MealRepository,
        photoStore: MealPhotoStore?,
        weightService: WeightService,
        heatmapService: ActivityHeatmapService,
        challengeService: ChallengeService,
        statsService: ProfileStatsService,
        friendService: any FriendService,
        coachService: CoachService,
        notificationCoordinator: NotificationCoordinator,
        unlockBus: AchievementUnlockBus
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.mealSaver = mealSaver
        self.todayState = todayState
        self.streakService = streakService
        self.accountDeletionService = accountDeletionService
        self.exportService = exportService
        self.csvExportService = csvExportService
        self.mealSearchService = mealSearchService
        self.streakCalendarService = streakCalendarService
        self.achievementService = achievementService
        self.calibrationService = calibrationService
        self.foodCatalog = foodCatalog
        self.progressState = progressState
        self.recipeRepository = recipeRepository
        self.mealRepository = mealRepository
        self.photoStore = photoStore
        self.weightService = weightService
        self.heatmapService = heatmapService
        self.challengeService = challengeService
        self.statsService = statsService
        self.friendService = friendService
        self.coachService = coachService
        self.notificationCoordinator = notificationCoordinator
        self.unlockBus = unlockBus
        self._router = State(initialValue: AppRouter(userRepository: userRepository))
    }

    var body: some View {
        Group {
            switch router.phase {
            case .launching:
                splash
            case .anonymous:
                AuthView(authService: authService)
                    .transition(.opacity)
            case .onboarding(let authUser):
                onboardingScene(for: authUser)
                    .transition(.opacity)
            case .main(let authUser):
                MainTabView(
                    authUser: authUser,
                    mealSaver: ChainedMealSaver(
                        underlying: mealSaver,
                        streakService: streakService,
                        achievementService: achievementService,
                        calibrationService: calibrationService,
                        notificationCoordinator: notificationCoordinator,
                        unlockBus: unlockBus,
                        userRemoteID: authUser.id
                    ),
                    exportService: exportService,
                    csvExportService: csvExportService,
                    mealSearchService: mealSearchService,
                    streakCalendarService: streakCalendarService,
                    achievementService: achievementService,
                    calibrationService: calibrationService,
                    foodCatalog: foodCatalog,
                    recipeRepository: recipeRepository,
                    mealRepository: mealRepository,
                    photoStore: photoStore,
                    weightService: weightService,
                    heatmapService: heatmapService,
                    challengeService: challengeService,
                    statsService: statsService,
                    friendService: friendService,
                    coachService: coachService,
                    unlockBus: unlockBus,
                    onSignOut: { Task { await authService.signOut() } },
                    onDeleteAccount: { Task { try? await accountDeletionService.deleteAccount() } },
                    todayState: todayState,
                    progressState: progressState
                )
                .transition(.opacity)
                .task(id: authUser.id) {
                    await notificationCoordinator.rescheduleAll(for: authUser.id)
                }
            }
        }
        .animation(Tokens.Motion.gentle, value: phaseKey)
        .task {
            if case .unknown = session.phase {
                await authService.restoreSession()
            }
            router.evaluate(authPhase: session.phase)
        }
        .onChange(of: session.phase) { _, _ in
            router.evaluate(authPhase: session.phase)
        }
    }

    private var splash: some View {
        ZStack {
            Tokens.Palette.background
                .ignoresSafeArea()
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Mealgram")
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
    }

    @ViewBuilder
    private func onboardingScene(for authUser: AuthUser) -> some View {
        OnboardingView(flow: freshFlow(for: authUser))
    }

    private var phaseKey: String {
        switch router.phase {
        case .launching: return "launching"
        case .anonymous: return "anonymous"
        case .onboarding(let user): return "onboarding-\(user.id)"
        case .main(let user): return "main-\(user.id)"
        }
    }

    private func freshFlow(for authUser: AuthUser) -> OnboardingFlow {
        if let existing = onboardingFlow { return existing }
        let flow = OnboardingFlow(
            authUser: authUser,
            userRepository: userRepository,
            onFinished: { [router, todayState, streakService] outcome in
                if outcome == .completed {
                    router.markOnboarded()
                    Task {
                        _ = try? streakService.currentStreak(for: authUser.id)
                        await todayState.refresh(for: authUser.id)
                    }
                }
            }
        )
        DispatchQueue.main.async { self.onboardingFlow = flow }
        return flow
    }
}

/// Wraps a `MealSaving` with the streak + achievement + calibration
/// side-effects. Keeps `SwiftDataMealSaver` pure while still letting one
/// save propagate the streak counter, any newly-unlocked achievement
/// banners, and the user's manual calibration factor.
private struct ChainedMealSaver: MealSaving {
    let underlying: any MealSaving
    let streakService: StreakService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let notificationCoordinator: NotificationCoordinator
    let unlockBus: AchievementUnlockBus
    let userRemoteID: String

    func save(meal: MealEntry) throws {
        // Apply the user-set calibration factor only to AI-derived
        // estimates — barcode + quick-database + voice entries are
        // user-controlled and shouldn't be silently scaled.
        if meal.source == .photoScan {
            let calibration = try? calibrationService.current(forUser: userRemoteID)
            if let factor = calibration?.portionAdjustmentFactor, factor != 1 {
                meal.portionMultiplier *= factor
            }
        }
        try underlying.save(meal: meal)
        Haptics.success()
        if meal.source == .photoScan {
            try? calibrationService.recordSample(forUser: userRemoteID)
        }
        try? streakService.registerLog(for: userRemoteID)
        if let unlocks = try? achievementService.evaluate(forUser: userRemoteID), !unlocks.isEmpty {
            unlockBus.push(unlocks)
            Haptics.medium()
            Task {
                for unlock in unlocks {
                    await notificationCoordinator.notifyAchievement(unlock)
                }
            }
        }
        Task { await notificationCoordinator.rescheduleAll(for: userRemoteID) }
    }
}
