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
    let achievementService: AchievementService
    let calibrationService: CalibrationService
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
        achievementService: AchievementService,
        calibrationService: CalibrationService,
        unlockBus: AchievementUnlockBus
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.mealSaver = mealSaver
        self.todayState = todayState
        self.streakService = streakService
        self.accountDeletionService = accountDeletionService
        self.exportService = exportService
        self.achievementService = achievementService
        self.calibrationService = calibrationService
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
                        unlockBus: unlockBus,
                        userRemoteID: authUser.id
                    ),
                    exportService: exportService,
                    achievementService: achievementService,
                    calibrationService: calibrationService,
                    unlockBus: unlockBus,
                    onSignOut: { Task { await authService.signOut() } },
                    onDeleteAccount: { Task { try? await accountDeletionService.deleteAccount() } },
                    todayState: todayState
                )
                .transition(.opacity)
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

/// Wraps a `MealSaving` with the streak + achievement side-effects. Keeps
/// `SwiftDataMealSaver` pure while still letting one save propagate the
/// streak counter and any newly-unlocked achievement banners.
private struct ChainedMealSaver: MealSaving {
    let underlying: any MealSaving
    let streakService: StreakService
    let achievementService: AchievementService
    let unlockBus: AchievementUnlockBus
    let userRemoteID: String

    func save(meal: MealEntry) throws {
        try underlying.save(meal: meal)
        try? streakService.registerLog(for: userRemoteID)
        if let unlocks = try? achievementService.evaluate(forUser: userRemoteID), !unlocks.isEmpty {
            unlockBus.push(unlocks)
        }
    }
}
