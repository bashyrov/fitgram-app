import SwiftUI

// swiftlint:disable type_body_length

/// Top-level navigation shell for authenticated users. Four tabs:
/// Today / Add (action sheet) / Progress / Profile.
struct MainTabView: View {
    let authUser: AuthUser
    let mealSaver: any MealSaving
    let exportService: DataExportService
    let csvExportService: MealCSVExportService
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
    let unlockBus: AchievementUnlockBus
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let todayState: TodayState
    let progressState: ProgressState

    @State private var addOptionsVisible = false
    @State private var isScanPresented = false
    @State private var isBarcodePresented = false
    @State private var isQuickDBPresented = false
    @State private var isVoicePresented = false
    @State private var isRecipesPresented = false
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
        unlockBus: AchievementUnlockBus,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void,
        todayState: TodayState,
        progressState: ProgressState
    ) {
        self.authUser = authUser
        self.mealSaver = mealSaver
        self.exportService = exportService
        self.csvExportService = csvExportService
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
        self.unlockBus = unlockBus
        self.onSignOut = onSignOut
        self.onDeleteAccount = onDeleteAccount
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

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                userRemoteID: authUser.id,
                state: todayState,
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
                yourID: authUser.id
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
                achievementService: achievementService,
                calibrationService: calibrationService,
                weightService: weightService,
                heatmapService: heatmapService,
                challengeService: challengeService,
                statsService: statsService,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount
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
        .confirmationDialog(
            "Jak chcesz dodać?",
            isPresented: $addOptionsVisible,
            titleVisibility: .visible
        ) {
            Button("📸 Zdjęcie posiłku") {
                isScanPresented = true
            }
            .accessibilityIdentifier(A11yID.Add.photoOption)
            Button("📦 Kod kreskowy") {
                isBarcodePresented = true
            }
            .accessibilityIdentifier(A11yID.Add.barcodeOption)
            Button("🔎 Szybka baza") {
                isQuickDBPresented = true
            }
            .accessibilityIdentifier(A11yID.Add.quickDBOption)
            Button("🎙 Powiedz na głos") {
                isVoicePresented = true
            }
            .accessibilityIdentifier(A11yID.Add.voiceOption)
            Button("📖 Mój przepis") {
                isRecipesPresented = true
            }
            .accessibilityIdentifier(A11yID.Add.recipeOption)
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
            try? await Task.sleep(nanoseconds: 5_000_000_000)
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
