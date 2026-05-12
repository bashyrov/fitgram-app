import SwiftData
import SwiftUI

@main
struct MealgramApp: App {
    @State private var session: AuthSession
    @State private var unlockBus: AchievementUnlockBus
    private let authService: AuthService
    private let persistenceController: PersistenceController
    private let userRepository: UserRepository
    private let mealSaver: any MealSaving
    private let streakService: StreakService
    private let achievementService: AchievementService
    private let calibrationService: CalibrationService
    private let todayState: TodayState
    private let accountDeletionService: AccountDeletionService
    private let exportService: DataExportService

    init() {
        let session = AuthSession()
        let providers: [any AuthProvider] = [
            AppleAuthProvider(),
            GoogleAuthProvider(),
            EmailAuthProvider(),
        ]
        let persistence = PersistenceController.shared
        self._session = State(initialValue: session)
        self._unlockBus = State(initialValue: AchievementUnlockBus())
        let authService = AuthService(providers: providers, session: session)
        self.authService = authService
        self.persistenceController = persistence
        self.userRepository = UserRepository(container: persistence.container)
        self.mealSaver = SwiftDataMealSaver(container: persistence.container)
        let streakService = StreakService(container: persistence.container)
        self.streakService = streakService
        self.achievementService = AchievementService(container: persistence.container)
        self.calibrationService = CalibrationService(container: persistence.container)
        self.todayState = TodayState(container: persistence.container, streakService: streakService)
        self.accountDeletionService = AccountDeletionService(
            authService: authService,
            persistence: persistence
        )
        self.exportService = DataExportService(container: persistence.container)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                userRepository: userRepository,
                mealSaver: mealSaver,
                todayState: todayState,
                streakService: streakService,
                accountDeletionService: accountDeletionService,
                exportService: exportService,
                achievementService: achievementService,
                calibrationService: calibrationService,
                unlockBus: unlockBus
            )
            .environment(session)
            .modelContainer(persistenceController.container)
            .tint(Tokens.Palette.primary)
        }
    }
}
