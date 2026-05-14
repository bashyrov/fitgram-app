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
    let onDeleteAccount: () -> Void
    let onRestartOnboarding: () -> Void
    let todayState: TodayState
    let progressState: ProgressState

    @State private var addOptionsVisible = false
    @State private var isScanPresented = false
    @State private var isBarcodePresented = false
    @State private var isQuickDBPresented = false
    @State private var isVoicePresented = false
    @State private var isRecipesPresented = false
    @State private var isManualEntryPresented = false
    @State private var isWeeklyDebriefPresented = false
    @State private var weeklyDebrief: WeeklyDebrief?
    @State private var isCoachHistoryPresented = false
    @State private var coachHistory: [CoachInsightLog] = []
    @State private var selectedMeal: MealEntry?
    @State private var undoSnapshot: MealEntrySnapshot?
    @State private var undoDismissTask: Task<Void, Never>?
    @State private var selectedTab: Tab = Self.initialTab()
    @State private var friendsState: FriendsState

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
        onDeleteAccount: @escaping () -> Void,
        onRestartOnboarding: @escaping () -> Void,
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
        self._friendsState = State(
            initialValue: FriendsState(service: friendService, userRemoteID: authUser.id)
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
                customGoalsService: goalsService,
                favoritesService: favoritesService,
                mealSaver: mealSaver,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                onOpenProfile: { selectedTab = .profile },
                onOpenScanner: { isScanPresented = true },
                onCookSuggested: { recipe in cookSuggested(recipe) },
                onCoachAction: { kind in handleCoachAction(kind) },
                onOpenWeeklyDebrief: { presentWeeklyDebrief() },
                onSelectMeal: { meal in selectedMeal = meal },
                onDismissInsight: { insight in
                    coachService.dismiss(insight: insight)
                    Task { await todayState.refresh(for: authUser.id) }
                }
            )
            .tabItem {
                Label("Dziś", systemImage: "sun.max.fill")
            }
            .tag(Tab.today)

            // Virtual tab — selecting it raises the add-options dialog and
            // bounces selection back to Today so the user never lands on an
            // empty scene.
            Color.clear
                .tabItem {
                    Label("Dodaj", systemImage: "plus.circle.fill")
                }
                .tag(Tab.add)

            WeekProgressView(userRemoteID: authUser.id, state: progressState)
                .tabItem {
                    Label("Tydzień", systemImage: "chart.bar.fill")
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
                Label("Znajomi", systemImage: "person.2.fill")
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
                Label("Profil", systemImage: "person.crop.circle")
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
        .onReceive(
            NotificationCenter.default.publisher(for: AppShortcutAction.showWeeklyDebrief)
        ) { _ in
            selectedTab = .today
            presentWeeklyDebrief()
        }
        .onReceive(NotificationCenter.default.publisher(for: AppShortcutAction.openRecipes)) { _ in
            isRecipesPresented = true
        }
        .onContinueUserActivity(CSSearchableItemActionType) { _ in
            isRecipesPresented = true
        }
        .confirmationDialog(
            "Jak chcesz dodać?",
            isPresented: $addOptionsVisible,
            titleVisibility: .visible
        ) {
            Button("📸 Zdjęcie posiłku") {
                gatedPresent(
                    kind: .photoScan,
                    cap: entitlementsStore.current.photoScansPerWeek,
                    trigger: .photoScanQuota,
                    onAllowed: { isScanPresented = true }
                )
            }
            .accessibilityIdentifier(A11yID.Add.photoOption)
            Button("📦 Kod kreskowy") {
                gatedPresent(
                    kind: .barcodeScan,
                    cap: entitlementsStore.current.barcodeScansPerWeek,
                    trigger: .barcodeScanQuota,
                    onAllowed: { isBarcodePresented = true }
                )
            }
            .accessibilityIdentifier(A11yID.Add.barcodeOption)
            Button("🔎 Szybka baza") {
                isQuickDBPresented = true
            }
            .accessibilityIdentifier(A11yID.Add.quickDBOption)
            Button("🎙 Powiedz na głos") {
                gatedPresent(
                    kind: .voiceEntry,
                    cap: entitlementsStore.current.voiceEntriesPerWeek,
                    trigger: .voiceEntryQuota,
                    onAllowed: { isVoicePresented = true }
                )
            }
            .accessibilityIdentifier(A11yID.Add.voiceOption)
            Button("📖 Mój przepis") {
                isRecipesPresented = true
            }
            .accessibilityIdentifier(A11yID.Add.recipeOption)
            Button("✍️ Wpisz ręcznie") {
                isManualEntryPresented = true
            }
            Button("Anuluj", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanRootView(
                detector: FoodDetectorFactory.make(),
                mealSaver: mealSaver,
                photoStore: photoStore,
                onDismiss: {
                    isScanPresented = false
                    refreshAfterSave()
                })
        }
        .fullScreenCover(isPresented: $isBarcodePresented) {
            BarcodeRootView(
                mealSaver: mealSaver,
                onDismiss: {
                    isBarcodePresented = false
                    refreshAfterSave()
                })
        }
        .sheet(isPresented: $isQuickDBPresented) {
            QuickDatabaseRootView(
                state: QuickDatabaseState(catalog: foodCatalog),
                mealSaver: mealSaver,
                onDismiss: {
                    isQuickDBPresented = false
                    refreshAfterSave()
                }
            )
        }
        .fullScreenCover(isPresented: $isVoicePresented) {
            VoiceRootView(
                mealSaver: mealSaver,
                parser: VoiceMealParser(catalog: (try? foodCatalog.all()) ?? []),
                onDismiss: {
                    isVoicePresented = false
                    refreshAfterSave()
                }
            )
        }
        .sheet(isPresented: $isRecipesPresented) {
            RecipeListView(
                state: RecipeListState(repository: recipeRepository),
                repository: recipeRepository,
                mealSaver: mealSaver,
                onDismiss: {
                    isRecipesPresented = false
                    refreshAfterSave()
                },
                estimator: makeRecipeEstimator()
            )
        }
        .sheet(isPresented: $isManualEntryPresented) {
            ManualEntryView(
                mealSaver: mealSaver,
                userRemoteID: authUser.id,
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator,
                onDismiss: {
                    isManualEntryPresented = false
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
                onDeleted: { snapshot in queueUndo(snapshot) }
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
    }

    private func makeRecipeEstimator() -> RecipeNutritionEstimator? {
        let foods = (try? foodCatalog.all()) ?? []
        guard !foods.isEmpty else { return nil }
        return RecipeNutritionEstimator(catalog: foods)
    }

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
        try? mealSaver.save(meal: snapshot.makeEntry())
        undoSnapshot = nil
        refreshAfterSave()
    }

    private func presentWeeklyDebrief() {
        weeklyDebrief = coachService.weeklyDebrief(for: authUser.id)
        isWeeklyDebriefPresented = true
    }

    private func refreshAfterSave() {
        Task {
            await todayState.refresh(for: authUser.id)
            await progressState.refresh(for: authUser.id)
        }
    }

    /// Quota gate for AI-backed scans. Free tier hits a weekly cap; raises
    /// the upgrade sheet with the matching trigger and short-circuits the
    /// flow. The usage counter is incremented inside ChainedMealSaver on
    /// successful meal save — opening the camera doesn't burn the quota.
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
        try? mealSaver.save(meal: entry)
        try? recipeRepository.save(recipe)
        refreshAfterSave()
    }
}
// swiftlint:enable type_body_length
