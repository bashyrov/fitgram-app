import SwiftUI

/// Top-level navigation shell for authenticated users. Three tabs — Today,
/// Add (raises an action sheet with the available capture modes), Profile.
/// Stripped-down for Phase 1; the Add menu will grow Quick Database +
/// Recipe pickers in Phase 2.
struct MainTabView: View {
    let authUser: AuthUser
    let mealSaver: any MealSaving
    let exportService: DataExportService
    let achievementService: AchievementService
    let calibrationService: CalibrationService
    let unlockBus: AchievementUnlockBus
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let todayState: TodayState

    @State private var addOptionsVisible = false
    @State private var isScanPresented = false
    @State private var isBarcodePresented = false
    @State private var selectedTab: Tab = .today

    enum Tab: Hashable {
        case today
        case add
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
            Button("Anuluj", role: .cancel) {}
        }
        .fullScreenCover(isPresented: $isScanPresented) {
            ScanRootView(
                detector: FoodDetectorFactory.make(),
                mealSaver: mealSaver,
                onDismiss: {
                    isScanPresented = false
                    Task { await todayState.refresh(for: authUser.id) }
                })
        }
        .fullScreenCover(isPresented: $isBarcodePresented) {
            BarcodeRootView(
                mealSaver: mealSaver,
                onDismiss: {
                    isBarcodePresented = false
                    Task { await todayState.refresh(for: authUser.id) }
                })
        }
    }
}
