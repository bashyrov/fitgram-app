import SwiftUI

/// Top-level navigation shell for authenticated users. Four tabs:
/// Today / Add (action sheet) / Progress / Profile.
struct MainTabView: View {
    let authUser: AuthUser
    let mealSaver: any MealSaving
    let exportService: DataExportService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let foodCatalog: any FoodCatalog
    let recipeRepository: RecipeRepository
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
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today
        case add
        case progress
        case profile
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(
                userRemoteID: authUser.id,
                state: todayState,
                onOpenProfile: { selectedTab = .profile },
                onOpenScanner: { isScanPresented = true }
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

            ProfileView(
                user: todayState.user,
                streak: todayState.streak,
                exportService: exportService,
                achievementService: achievementService,
                calibrationService: calibrationService,
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
        .animation(Tokens.Motion.gentle, value: unlockBus.queue.count)
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
            Button("📦 Kod kreskowy") {
                isBarcodePresented = true
            }
            Button("🔎 Szybka baza") {
                isQuickDBPresented = true
            }
            Button("🎙 Powiedz na głos") {
                isVoicePresented = true
            }
            Button("📖 Mój przepis") {
                isRecipesPresented = true
            }
            Button("Anuluj", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanRootView(
                detector: FoodDetectorFactory.make(),
                mealSaver: mealSaver,
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
                }
            )
        }
    }

    private func refreshAfterSave() {
        Task {
            await todayState.refresh(for: authUser.id)
            await progressState.refresh(for: authUser.id)
        }
    }
}
