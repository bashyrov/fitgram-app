import CoreSpotlight
import SwiftUI

// swiftlint:disable type_body_length file_length

/// Top-level navigation shell for authenticated users. Four tabs:
/// Today / Add (action sheet) / Progress / Profile.
struct MainTabView: View {
    let authUser: AuthUser
    let mealSaver: any MealSaving
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
    let bundleExportService: DataBundleExportService
    let mealSearchService: MealSearchService
    let streakCalendarService: StreakCalendarService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let foodCatalog: any FoodCatalog
    let recipeRepository: RecipeRepository
    let mealRepository: MealRepository
    let photoStore: MealPhotoStore?
    let weightService: WeightService
    let goalTrackingService: GoalTrackingService
    let notificationCoordinator: NotificationCoordinator
    let heatmapService: ActivityHeatmapService
    let challengeService: ChallengeService
    let statsService: ProfileStatsService
    let friendService: any FriendService
    let coachService: CoachService
    let userProfileService: UserProfileService
    let goalsService: GoalsService
    let privacyStore: PrivacyStore
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let paywallCoordinator: PaywallCoordinator
    let favoritesService: FavoritesService
    let unlockBus: AchievementUnlockBus
    let onSignOut: () -> Void
    let onDeleteAccount: () async throws -> Void
    let onRestartOnboarding: () throws -> Void
    let todayState: TodayState
    let progressState: ProgressState
    let voiceParser: VoiceMealParser
    let mealTextAnalyzer: MealTextAnalysisService
    let olaChefWorkerService: WorkerOlaChefService?

    @State private var addOptionsVisible = false
    @State private var isScanPresented = false
    @State private var isBarcodePresented = false
    #if DEBUG
    @State private var debugScanResultPresented = false
    static let demoScanResult = ScanResult(
        items: [
            .init(
                name: "Schabowy",
                quantityGrams: 180,
                caloriesKcal: 420,
                proteinGrams: 32,
                carbsGrams: 18,
                fatGrams: 22,
                confidence: 0.93
            ),
            .init(
                name: "Ziemniaki gotowane",
                quantityGrams: 200,
                caloriesKcal: 160,
                proteinGrams: 4,
                carbsGrams: 36,
                fatGrams: 0.3,
                confidence: 0.96
            ),
            .init(
                name: "Surówka z kapusty",
                quantityGrams: 120,
                caloriesKcal: 60,
                proteinGrams: 1.4,
                carbsGrams: 8,
                fatGrams: 3,
                confidence: 0.81
            ),
        ],
        suggestedMealType: .lunch,
        confidence: 0.9,
        rawAINotes: nil
    )
    #endif
    @State private var isQuickDBPresented = false
    @State private var repeatedMeal: MealEntrySnapshot?
    @State private var isVoicePresented = false
    @State private var isRecipesPresented = false
    @State private var isManualEntryPresented = false
    @State private var isOlaChefPresented = false
    @State private var isFavoritesListPresented = false
    @State private var isWeeklyDebriefPresented = false
    @State private var weeklyDebrief: WeeklyDebrief?
    @State private var isCoachHistoryPresented = false
    @State private var coachHistory: [CoachInsightLog] = []
    @State private var selectedMeal: MealEntry?
    @State private var undoSnapshot: MealEntrySnapshot?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var selectedTab: Tab = Self.initialTab()
    @State private var friendsState: FriendsState
    @State private var goalTrackingState: GoalTrackingState
    @State private var isGoalTrackingPresented = false
    @State private var saveError: String?

    init(
        authUser: AuthUser,
        mealSaver: any MealSaving,
        exportService: DataExportService,
        csvExportService: MealCSVExportService,
        bundleExportService: DataBundleExportService,
        mealSearchService: MealSearchService,
        streakCalendarService: StreakCalendarService,
        achievementService: AchievementService,
        calibrationService: CalibrationService,
        foodCatalog: any FoodCatalog,
        recipeRepository: RecipeRepository,
        mealRepository: MealRepository,
        photoStore: MealPhotoStore?,
        weightService: WeightService,
        goalTrackingService: GoalTrackingService,
        notificationCoordinator: NotificationCoordinator,
        heatmapService: ActivityHeatmapService,
        challengeService: ChallengeService,
        statsService: ProfileStatsService,
        friendService: any FriendService,
        coachService: CoachService,
        userProfileService: UserProfileService,
        goalsService: GoalsService,
        privacyStore: PrivacyStore,
        entitlementsStore: EntitlementsStore,
        usageMeter: UsageMeter,
        paywallCoordinator: PaywallCoordinator,
        favoritesService: FavoritesService,
        unlockBus: AchievementUnlockBus,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () async throws -> Void,
        onRestartOnboarding: @escaping () throws -> Void,
        todayState: TodayState,
        progressState: ProgressState
    ) {
        self.authUser = authUser
        self.mealSaver = mealSaver
        self.exportService = exportService
        self.csvExportService = csvExportService
        self.bundleExportService = bundleExportService
        self.mealSearchService = mealSearchService
        self.streakCalendarService = streakCalendarService
        self.achievementService = achievementService
        self.calibrationService = calibrationService
        self.foodCatalog = foodCatalog
        self.recipeRepository = recipeRepository
        self.mealRepository = mealRepository
        self.photoStore = photoStore
        self.weightService = weightService
        self.goalTrackingService = goalTrackingService
        self.notificationCoordinator = notificationCoordinator
        self.heatmapService = heatmapService
        self.challengeService = challengeService
        self.statsService = statsService
        self.friendService = friendService
        self.coachService = coachService
        self.userProfileService = userProfileService
        self.goalsService = goalsService
        self.privacyStore = privacyStore
        self.entitlementsStore = entitlementsStore
        self.usageMeter = usageMeter
        self.paywallCoordinator = paywallCoordinator
        self.favoritesService = favoritesService
        self.unlockBus = unlockBus
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
        self.onRestartOnboarding = onRestartOnboarding
        self.todayState = todayState
        self.progressState = progressState
        let foods = (try? foodCatalog.all()) ?? []
        self.voiceParser = VoiceMealParser(catalog: foods)
        let mealTextClient: (any APIClient)? = AppConfig.workerBaseURL.map { baseURL in
            URLSessionAPIClient(
                baseURL: baseURL,
                interceptors: [AuthInterceptor(), TimeZoneInterceptor(), LoggingInterceptor()]
            ) as any APIClient
        }
        self.mealTextAnalyzer = MealTextAnalysisService(
            client: mealTextClient,
            catalog: foods,
            foodCatalog: foodCatalog
        )
        self.olaChefWorkerService = mealTextClient.map { WorkerOlaChefService(client: $0) }
        self._friendsState = State(
            initialValue: FriendsState(service: friendService, userRemoteID: authUser.id)
        )
        self._goalTrackingState = State(
            initialValue: GoalTrackingState(
                service: goalTrackingService,
                notificationCoordinator: notificationCoordinator
            )
        )
    }

    enum Tab: Hashable {
        case today
        case add
        case progress
        case friends
        case profile
    }

    private static func initialTab() -> Tab {
        #if DEBUG
        switch DebugBypass.initialTab {
        case "progress": return .progress
        case "profile": return .profile
        case "friends": return .friends
        default: return .today
        }
        #else
        return .today
        #endif
    }

    private var tabSelectionBinding: Binding<Tab> {
        Binding(
            get: { selectedTab },
            set: { newValue in
                if newValue == selectedTab, newValue == .today {
                    NotificationCenter.default.post(
                        name: AppShortcutAction.scrollTodayToTop, object: nil
                    )
                }
                selectedTab = newValue
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelectionBinding) {
            TodayView(
                userRemoteID: authUser.id,
                state: todayState,
                favoritesService: favoritesService,
                mealSaver: mealSaver,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                goalTrackingState: goalTrackingState,
                onOpenProfile: { selectedTab = .profile },
                onOpenScanner: { isScanPresented = true },
                onOpenAddOptions: { addOptionsVisible = true },
                onOpenGoalTracking: {
                    goalTrackingState.refresh(for: authUser.id)
                    isGoalTrackingPresented = true
                },
                onCookSuggested: { recipe in cookSuggested(recipe) },
                onCoachAction: { kind in handleCoachAction(kind) },
                onSelectMeal: { meal in selectedMeal = meal },
                onDismissInsight: { insight in
                    coachService.dismiss(insight: insight)
                    Task { await todayState.refresh(for: authUser.id) }
                }
            )
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .tag(Tab.today)

            // Virtual tab — selecting it raises the add-options dialog and
            // bounces selection back to Today so the user never lands on an
            // empty scene.
            Color.clear
                .tabItem {
                    Label("Add", systemImage: "plus.circle.fill")
                }
                .tag(Tab.add)

            WeekProgressView(
                userRemoteID: authUser.id,
                state: progressState,
                onOpenWeeklyDebrief: { presentWeeklyDebrief() }
            )
            .tabItem {
                Label("Week", systemImage: "chart.bar.fill")
            }
            .tag(Tab.progress)

            FriendsRootView(
                state: friendsState,
                yourStreak: todayState.streak?.currentLength ?? 0,
                yourDisplayName: todayState.user?.displayName ?? "Ty",
                yourID: authUser.id,
                friendService: friendService
            )
            .tabItem {
                Label("Friends", systemImage: "person.2.fill")
            }
            .tag(Tab.friends)

            ProfileView(
                user: todayState.user,
                streak: todayState.streak,
                exportService: exportService,
                csvExportService: csvExportService,
                bundleExportService: bundleExportService,
                mealSearchService: mealSearchService,
                mealRepository: mealRepository,
                photoStore: photoStore,
                streakCalendarService: streakCalendarService,
                achievementService: achievementService,
                calibrationService: calibrationService,
                weightService: weightService,
                heatmapService: heatmapService,
                challengeService: challengeService,
                statsService: statsService,
                userProfileService: userProfileService,
                goalsService: goalsService,
                privacyStore: privacyStore,
                entitlementsStore: entitlementsStore,
                usageMeter: usageMeter,
                paywallCoordinator: paywallCoordinator,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount,
                onRestartOnboarding: onRestartOnboarding
            )
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
        }
        .tint(Tokens.Palette.primary)
        .overlay(alignment: .top) {
            if let current = unlockBus.current {
                AchievementUnlockBanner(definition: current) {
                    unlockBus.consume()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .padding(.top, Tokens.Space.lg)
            }
        }
        .overlay(alignment: .bottom) {
            if let snapshot = undoSnapshot {
                MealUndoBanner(
                    snapshot: snapshot,
                    onUndo: { performUndo(snapshot) },
                    onDismiss: { dismissUndo() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
        .animation(Tokens.Motion.gentle, value: unlockBus.queue.count)
        .animation(Tokens.Motion.gentle, value: undoSnapshot?.id)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .add {
                addOptionsVisible = true
                selectedTab = .today
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppShortcutAction.logMeal)) { _ in
            selectedTab = .today
            addOptionsVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AppShortcutAction.showToday)) { _ in
            selectedTab = .today
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("MealgramDebugSwitchTab"))) { note in
            guard let name = note.userInfo?["tab"] as? String else { return }
            switch name {
            case "today": selectedTab = .today
            case "week", "progress": selectedTab = .progress
            case "friends": selectedTab = .friends
            case "profile": selectedTab = .profile
            default: break
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AppShortcutAction.showWeeklyDebrief)
        ) { _ in
            selectedTab = .today
            presentWeeklyDebrief()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppShortcutAction.openRecipes)) { _ in
            isRecipesPresented = true
        }
        .onReceive(NotificationCenter.default.publisher(for: AppShortcutAction.mainGoalChanged)) { _ in
            refreshAfterGoalsChange()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AppShortcutAction.addWaterFromActivity)
        ) { _ in
            selectedTab = .today
            Task {
                _ = await todayState.logWaterGlass(for: authUser.id)
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("MealgramMealSaved"))
        ) { _ in
            refreshAfterSave()
        }
        .onReceive(
            NotificationCenter.default.publisher(for: Notification.Name("MealgramLanguageChanged"))
        ) { _ in
            Task {
                // Force the cached Coach copy to rebuild in the new locale.
                try? userProfileService.refreshRecommendationsForUser(remoteID: authUser.id)
                await todayState.refresh(for: authUser.id)
                goalTrackingState.refresh(for: authUser.id)
            }
        }
        .onContinueUserActivity(CSSearchableItemActionType) { _ in
            isRecipesPresented = true
        }
        .alert(
            "Nie udało się zapisać posiłku",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Spróbuj ponownie.")
        }
        .sheet(isPresented: $addOptionsVisible) {
            AddMealSheet(
                entitlementsStore: entitlementsStore,
                usageMeter: usageMeter,
                onPhotoScan: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        gatedPresent(
                            kind: .photoScan,
                            cap: entitlementsStore.current.photoScansPerWeek,
                            trigger: .photoScanQuota,
                            onAllowed: { isScanPresented = true }
                        )
                    }
                },
                onBarcode: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        gatedPresent(
                            kind: .barcodeScan,
                            cap: entitlementsStore.current.barcodeScansPerWeek,
                            trigger: .barcodeScanQuota,
                            onAllowed: { isBarcodePresented = true }
                        )
                    }
                },
                onQuickDB: {
                    // SwiftUI can't dismiss + present a sheet in the same
                    // render cycle — schedule the new sheet after the
                    // AddMealSheet finishes its dismissal animation.
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        isQuickDBPresented = true
                    }
                },
                onRecentMeal: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        if let latest = mealRepository.latestRepeatableMealSnapshot() {
                            repeatedMeal = latest
                        } else {
                            isQuickDBPresented = true
                        }
                    }
                },
                onVoice: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        gatedPresent(
                            kind: .voiceEntry,
                            cap: entitlementsStore.current.voiceEntriesPerWeek,
                            trigger: .voiceEntryQuota,
                            onAllowed: { isVoicePresented = true }
                        )
                    }
                },
                onRecipe: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        isFavoritesListPresented = true
                    }
                },
                onManual: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        isManualEntryPresented = true
                    }
                },
                onOlaChef: {
                    addOptionsVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                        isOlaChefPresented = true
                    }
                },
                onCancel: { addOptionsVisible = false }
            )
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanRootView(
                detector: FoodDetectorFactory.make(),
                mealSaver: mealSaver,
                photoStore: photoStore,
                onDismiss: {
                    isScanPresented = false
                    refreshAfterSave()
                },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .fullScreenCover(isPresented: $isBarcodePresented) {
            BarcodeRootView(
                mealSaver: mealSaver,
                onDismiss: {
                    isBarcodePresented = false
                    refreshAfterSave()
                },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .sheet(isPresented: $isQuickDBPresented) {
            QuickDatabaseRootView(
                state: QuickDatabaseState(catalog: foodCatalog),
                mealSaver: mealSaver,
                onDismiss: {
                    isQuickDBPresented = false
                    refreshAfterSave()
                },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .sheet(item: $repeatedMeal) { snapshot in
            FoodDetailSheet(
                repeating: snapshot,
                onSave: { items in
                    let entry = MealEntry(
                        mealType: snapshot.mealType,
                        source: snapshot.source,
                        notes: snapshot.notes,
                        tags: snapshot.tags,
                        items: items
                    )
                    do {
                        try mealSaver.save(meal: entry)
                    } catch {
                        Haptics.warning()
                        saveError = L("Couldn't save. Try again.")
                    }
                },
                onDismiss: {
                    repeatedMeal = nil
                    refreshAfterSave()
                },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .fullScreenCover(isPresented: $isVoicePresented) {
            VoiceRootView(
                mealSaver: mealSaver,
                parser: voiceParser,
                mealAnalyzer: mealTextAnalyzer,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                usageMeter: usageMeter,
                onDismiss: {
                    isVoicePresented = false
                    refreshAfterSave()
                }
            )
        }
        #if DEBUG
        .fullScreenCover(isPresented: $debugScanResultPresented) {
            ScanResultView(
                result: MainTabView.demoScanResult,
                imageData: nil,
                onSave: { _, _ in debugScanResultPresented = false },
                onRetake: { debugScanResultPresented = false },
                onDismiss: { debugScanResultPresented = false },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .task {
            await presentInitialDebugSurfaceIfNeeded()
        }
        #endif
        .sheet(isPresented: $isRecipesPresented) {
            RecipeListView(
                state: RecipeListState(repository: recipeRepository),
                repository: recipeRepository,
                mealSaver: mealSaver,
                onDismiss: {
                    isRecipesPresented = false
                    refreshAfterSave()
                },
                estimator: makeRecipeEstimator(),
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter
            )
        }
        .sheet(isPresented: $isManualEntryPresented) {
            ManualEntryView(
                mealSaver: mealSaver,
                userRemoteID: authUser.id,
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                usageMeter: usageMeter,
                mealAnalyzer: mealTextAnalyzer,
                onDismiss: {
                    isManualEntryPresented = false
                    refreshAfterSave()
                }
            )
        }
        .fullScreenCover(isPresented: $isOlaChefPresented) {
            OlaChefView(
                mealSaver: mealSaver,
                userRemoteID: authUser.id,
                entitlementsStore: entitlementsStore,
                usageMeter: usageMeter,
                paywallCoordinator: paywallCoordinator,
                favoritesService: favoritesService,
                workerService: olaChefWorkerService,
                onDismiss: {
                    isOlaChefPresented = false
                    refreshAfterSave()
                }
            )
        }
        .sheet(isPresented: $isFavoritesListPresented) {
            FavoritesListView(
                userRemoteID: authUser.id,
                favoritesService: favoritesService,
                mealSaver: mealSaver,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                mealAnalyzer: mealTextAnalyzer,
                usageMeter: usageMeter,
                onAddNew: {
                    isFavoritesListPresented = false
                    isManualEntryPresented = true
                },
                onDismiss: {
                    isFavoritesListPresented = false
                    refreshAfterSave()
                }
            )
        }
        .sheet(item: $selectedMeal) { meal in
            MealDetailSheet(
                meal: meal,
                repository: mealRepository,
                photoStore: photoStore,
                onDismiss: { selectedMeal = nil },
                onChanged: { refreshAfterSave() },
                onDeleted: { snapshot in queueUndo(snapshot) },
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                userRemoteID: authUser.id
            )
        }
        .sheet(isPresented: $isWeeklyDebriefPresented) {
            if let debrief = weeklyDebrief {
                WeeklyDebriefView(
                    debrief: debrief,
                    onDismiss: { isWeeklyDebriefPresented = false },
                    onCoachAction: { kind in
                        isWeeklyDebriefPresented = false
                        handleCoachAction(kind)
                    },
                    onOpenHistory: { presentCoachHistory() },
                    existingFeedback: coachService.feedback(for: authUser.id),
                    onFeedback: { value in
                        coachService.recordFeedback(helpful: value, for: authUser.id)
                    }
                )
            }
        }
        .sheet(isPresented: $isCoachHistoryPresented) {
            CoachHistoryView(
                logs: coachHistory,
                decode: { coachService.decode(log: $0) },
                onDismiss: { isCoachHistoryPresented = false }
            )
        }
        .sheet(isPresented: $isGoalTrackingPresented) {
            GoalTrackingView(
                userRemoteID: authUser.id,
                state: goalTrackingState,
                onDismiss: { isGoalTrackingPresented = false },
                tips: goalTipsForCurrentUser()
            )
        }
    }

    private func refreshAfterGoalsChange() {
        goalTrackingState.refresh(for: authUser.id)
        Task {
            await todayState.refresh(for: authUser.id)
            await progressState.refresh(for: authUser.id)
        }
    }

    /// Looks up the cached Recommendations payload on the current user
    /// and returns up to 3 inline tips for the goal-tracking sheet.
    /// Falls back to an empty array if recommendations haven't been
    /// fetched yet — caller handles the empty case gracefully.
    private func goalTipsForCurrentUser() -> [RecommendationTip] {
        guard let user = todayState.user,
            let recs = RuleBasedRecommendationsService.buildSync(for: user)
        else { return [] }
        return Array(recs.tips.prefix(3))
    }

    private func makeRecipeEstimator() -> RecipeNutritionEstimator? {
        let foods = (try? foodCatalog.all()) ?? []
        guard !foods.isEmpty else { return nil }
        return RecipeNutritionEstimator(catalog: foods)
    }

    #if DEBUG
    @MainActor
    private func presentInitialDebugSurfaceIfNeeded() async {
        // Small delay so user data + tab content settle before a sheet pops.
        try? await Task.sleep(nanoseconds: 700_000_000)
        switch ProcessInfo.processInfo.environment["MEALGRAM_DEBUG_PRESENT"] {
        case "scanner":
            isScanPresented = true
        case "scan-result":
            debugScanResultPresented = true
        case "goal":
            goalTrackingState.refresh(for: authUser.id)
            isGoalTrackingPresented = true
        case "add-meal":
            addOptionsVisible = true
        case "recipes":
            isRecipesPresented = true
        case "quick-db":
            isQuickDBPresented = true
        case "weekly-debrief":
            presentWeeklyDebrief()
        case "voice":
            isVoicePresented = true
        case "manual":
            isManualEntryPresented = true
        default:
            break
        }
    }
    #endif

    private func presentCoachHistory() {
        coachHistory = coachService.history(for: authUser.id)
        isCoachHistoryPresented = true
    }

    private func queueUndo(_ snapshot: MealEntrySnapshot) {
        undoDismissTask?.cancel()
        undoSnapshot = snapshot
        undoDismissTask = Task { [snapshotID = snapshot.id] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            if undoSnapshot?.id == snapshotID {
                undoSnapshot = nil
            }
        }
    }

    private func dismissUndo() {
        undoDismissTask?.cancel()
        undoSnapshot = nil
    }

    private func performUndo(_ snapshot: MealEntrySnapshot) {
        undoDismissTask?.cancel()
        do {
            try mealSaver.save(meal: snapshot.makeEntry())
            undoSnapshot = nil
            refreshAfterSave()
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    private func presentWeeklyDebrief() {
        guard entitlementsStore.current.canUseOlaAdvice,
            usageMeter.canUse(.coachDebrief, cap: entitlementsStore.current.coachWeeklyDebriefsPerWeek)
        else {
            paywallCoordinator.present(.coachDebriefQuota)
            return
        }
        Task {
            weeklyDebrief = await coachService.weeklyDebrief(for: authUser.id)
            usageMeter.record(.coachDebrief, cap: entitlementsStore.current.coachWeeklyDebriefsPerWeek)
            isWeeklyDebriefPresented = true
        }
    }

    private func refreshAfterSave() {
        Task {
            await todayState.refresh(for: authUser.id)
            await progressState.refresh(for: authUser.id)
            goalTrackingState.refresh(for: authUser.id)
        }
    }

    /// Quota gate for free-tier AI entry points. Usage is recorded only
    /// after a meal is actually saved, but opening a new AI flow is blocked
    /// once today's local-day allowance is exhausted.
    private func gatedPresent(
        kind: UsageMeter.Kind,
        cap: Int?,
        trigger: PaywallTrigger,
        onAllowed: () -> Void
    ) {
        if usageMeter.canUse(kind, cap: cap) {
            onAllowed()
        } else {
            paywallCoordinator.present(trigger)
        }
    }

    private func handleCoachAction(_ kind: CoachInsight.ActionKind) {
        switch kind {
        case .openScanner: isScanPresented = true
        case .openQuickDB: isQuickDBPresented = true
        case .openRecipes: isRecipesPresented = true
        case .openWeightLog: selectedTab = .profile
        }
    }

    /// One-tap cook from the Today suggestion card. Saves through the same
    /// MealSaving pipeline as every other entry path, then refreshes the
    /// dashboards.
    private func cookSuggested(_ recipe: Recipe) {
        let entry = recipeRepository.cook(recipe)
        do {
            try mealSaver.save(meal: entry)
            try recipeRepository.save(recipe)
            refreshAfterSave()
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }
}
// swiftlint:enable type_body_length
