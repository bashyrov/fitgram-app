import SwiftUI

/// Top-level navigation shell for authenticated users. Three tabs — Today,
/// Add (raises the full-screen scanner), Profile. Stripped-down for
/// Phase 1; the Add tab will house the Quick Database + Recipe pickers in
/// Phase 2.
struct MainTabView: View {
    let authUser: AuthUser
    let mealSaver: any MealSaving
    let exportService: DataExportService
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void
    let todayState: TodayState

    @State private var isScanPresented = false
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

            // Visible "Add" tab is the affordance; selecting it just opens
            // the modal scanner so we never present an empty scene.
            Color.clear
                .tabItem {
                    Label("Dodaj", systemImage: "plus.circle.fill")
                }
                .tag(Tab.add)

            ProfileView(
                user: todayState.user,
                streak: todayState.streak,
                exportService: exportService,
                onSignOut: onSignOut,
                onDeleteAccount: onDeleteAccount
            )
            .tabItem {
                Label("Profil", systemImage: "person.crop.circle")
            }
            .tag(Tab.profile)
        }
        .tint(Tokens.Palette.primary)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .add {
                isScanPresented = true
                selectedTab = .today
            }
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
    }
}
