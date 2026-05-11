import SwiftData
import SwiftUI

@main
struct MealgramApp: App {
    @State private var session: AuthSession
    private let authService: AuthService
    private let persistenceController: PersistenceController
    private let userRepository: UserRepository
    private let mealSaver: any MealSaving
    private let streakService: StreakService
    private let todayState: TodayState
    private let accountDeletionService: AccountDeletionService

    init() {
        let session = AuthSession()
        let providers: [any AuthProvider] = [
            AppleAuthProvider(),
            GoogleAuthProvider(),
            EmailAuthProvider(),
        ]
        let persistence = PersistenceController.shared
        self._session = State(initialValue: session)
        let authService = AuthService(providers: providers, session: session)
        self.authService = authService
        self.persistenceController = persistence
        self.userRepository = UserRepository(container: persistence.container)
        self.mealSaver = SwiftDataMealSaver(container: persistence.container)
        let streakService = StreakService(container: persistence.container)
        self.streakService = streakService
        self.todayState = TodayState(container: persistence.container, streakService: streakService)
        self.accountDeletionService = AccountDeletionService(
            authService: authService,
            persistence: persistence
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                userRepository: userRepository,
                mealSaver: mealSaver,
                todayState: todayState,
                streakService: streakService,
                accountDeletionService: accountDeletionService
            )
            .environment(session)
            .modelContainer(persistenceController.container)
            .tint(Tokens.Palette.primary)
        }
    }
}
