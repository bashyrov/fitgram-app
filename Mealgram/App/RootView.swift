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
    let bundleExportService: DataBundleExportService
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
    let goalTrackingService: GoalTrackingService
    let heatmapService: ActivityHeatmapService
    let challengeService: ChallengeService
    let statsService: ProfileStatsService
    let friendService: any FriendService
    let coachService: CoachService
    let notificationCoordinator: NotificationCoordinator
    let unlockBus: AchievementUnlockBus
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let recommendationsService: RecommendationsService
    let privacyStore: PrivacyStore
    let subscriptionService: any SubscriptionService
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let paywallCoordinator: PaywallCoordinator
    let favoritesService: FavoritesService
    let toastCenter: ToastCenter

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
        bundleExportService: DataBundleExportService,
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
        goalTrackingService: GoalTrackingService,
        heatmapService: ActivityHeatmapService,
        challengeService: ChallengeService,
        statsService: ProfileStatsService,
        friendService: any FriendService,
        coachService: CoachService,
        notificationCoordinator: NotificationCoordinator,
        unlockBus: AchievementUnlockBus,
        userProfileService: UserProfileService,
        goalsService: GoalsService,
        recommendationsService: RecommendationsService,
        privacyStore: PrivacyStore,
        subscriptionService: any SubscriptionService,
        entitlementsStore: EntitlementsStore,
        usageMeter: UsageMeter,
        paywallCoordinator: PaywallCoordinator,
        favoritesService: FavoritesService,
        toastCenter: ToastCenter
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.mealSaver = mealSaver
        self.todayState = todayState
        self.streakService = streakService
        self.accountDeletionService = accountDeletionService
        self.exportService = exportService
        self.csvExportService = csvExportService
        self.bundleExportService = bundleExportService
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
        self.goalTrackingService = goalTrackingService
        self.heatmapService = heatmapService
        self.challengeService = challengeService
        self.statsService = statsService
        self.friendService = friendService
        self.coachService = coachService
        self.notificationCoordinator = notificationCoordinator
        self.unlockBus = unlockBus
        self.userProfileService = userProfileService
        self.goalsService = goalsService
        self.recommendationsService = recommendationsService
        self.privacyStore = privacyStore
        self.subscriptionService = subscriptionService
        self.entitlementsStore = entitlementsStore
        self.usageMeter = usageMeter
        self.paywallCoordinator = paywallCoordinator
        self.favoritesService = favoritesService
        self.toastCenter = toastCenter
        self._router = State(initialValue: AppRouter(userRepository: userRepository))
    }

    @AppStorage("preferences.theme") private var themeRaw = ThemePreference.auto.rawValue

    private var themePreference: ThemePreference {
        ThemePreference(rawValue: themeRaw) ?? .auto
    }

    var body: some View {
        rootContent
            .preferredColorScheme(themePreference.colorScheme)
            .overlay(alignment: .top) {
                ToastOverlay(center: toastCenter)
            }
            .sheet(
                isPresented: Binding(
                    get: { paywallCoordinator.activeTrigger != nil },
                    set: { newValue in
                        if !newValue { paywallCoordinator.dismiss() }
                    }
                )
            ) {
                if let trigger = paywallCoordinator.activeTrigger {
                    UpgradeSheet(
                        trigger: trigger,
                        subscriptionService: subscriptionService,
                        onDismiss: {
                            entitlementsStore.reconcile()
                            paywallCoordinator.dismiss()
                        }
                    )
                }
            }
    }

    @ViewBuilder
    private var rootContent: some View {
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
                        userRemoteID: authUser.id,
                        usageMeter: usageMeter,
                        entitlementsStore: entitlementsStore
                    ),
                    exportService: exportService,
                    csvExportService: csvExportService,
                    bundleExportService: bundleExportService,
                    mealSearchService: mealSearchService,
                    streakCalendarService: streakCalendarService,
                    achievementService: achievementService,
                    calibrationService: calibrationService,
                    foodCatalog: foodCatalog,
                    recipeRepository: recipeRepository,
                    mealRepository: mealRepository,
                    photoStore: photoStore,
                    weightService: weightService,
                    goalTrackingService: goalTrackingService,
                    notificationCoordinator: notificationCoordinator,
                    heatmapService: heatmapService,
                    challengeService: challengeService,
                    statsService: statsService,
                    friendService: friendService,
                    coachService: coachService,
                    userProfileService: userProfileService,
                    goalsService: goalsService,
                    privacyStore: privacyStore,
                    entitlementsStore: entitlementsStore,
                    usageMeter: usageMeter,
                    paywallCoordinator: paywallCoordinator,
                    favoritesService: favoritesService,
                    unlockBus: unlockBus,
                    onSignOut: { Task { await authService.signOut() } },
                    onDeleteAccount: {
                        try await accountDeletionService.deleteAccount()
                    },
                    onRestartOnboarding: {
                        try userRepository.resetOnboarding(forRemoteID: authUser.id)
                        onboardingFlow = nil
                        router.restartOnboarding()
                    },
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
        OnboardingView(
            flow: freshFlow(for: authUser),
            subscriptionService: subscriptionService
        )
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
            recommendationsService: recommendationsService,
            userProfileService: userProfileService,
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
    let usageMeter: UsageMeter
    let entitlementsStore: EntitlementsStore

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
        recordQuotaUsage(for: meal.source)
        if meal.source == .photoScan {
            try? calibrationService.recordSample(forUser: userRemoteID)
        }
        try? streakService.registerLog(for: userRemoteID)
        if let unlocks = try? achievementService.evaluateAfterSaving(
            meal: meal,
            forUser: userRemoteID
        ),
            !unlocks.isEmpty
        {
            unlockBus.push(unlocks)
            Haptics.medium()
            Task {
                for unlock in unlocks {
                    await notificationCoordinator.notifyAchievement(unlock)
                }
            }
        }
        Task { await notificationCoordinator.rescheduleAll(for: userRemoteID) }
        // Broadcast — TodayState + ProgressState listen and refresh.
        // Belt-and-braces guard for paths that bypass the sheet onDismiss
        // (e.g., a save that completes after the sheet is already gone).
        NotificationCenter.default.post(
            name: Notification.Name("MealgramMealSaved"),
            object: nil,
            userInfo: ["userRemoteID": userRemoteID]
        )
    }

    /// Bumps the relevant weekly counter when an AI-backed entry path
    /// produces a saved meal. Free tier ↦ counts toward the cap; premium
    /// ↦ no-op because cap is nil.
    private func recordQuotaUsage(for source: MealSource) {
        let entitlements = entitlementsStore.current
        switch source {
        case .photoScan:
            usageMeter.record(.photoScan, cap: entitlements.photoScansPerWeek)
        case .barcode:
            usageMeter.record(.barcodeScan, cap: entitlements.barcodeScansPerWeek)
        case .voice:
            usageMeter.record(.voiceEntry, cap: entitlements.voiceEntriesPerWeek)
        case .quickDatabase, .recipe, .manual:
            break
        }
    }
}
