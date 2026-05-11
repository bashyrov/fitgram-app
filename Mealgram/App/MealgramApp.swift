import SwiftData
import SwiftUI

@main
struct MealgramApp: App {
    @State private var session: AuthSession
    private let authService: AuthService
    private let persistenceController: PersistenceController
    private let userRepository: UserRepository
    private let mealSaver: any MealSaving

    init() {
        let session = AuthSession()
        let providers: [any AuthProvider] = [
            AppleAuthProvider(),
            GoogleAuthProvider(),
            EmailAuthProvider(),
        ]
        let persistence = PersistenceController.shared
        self._session = State(initialValue: session)
        self.authService = AuthService(providers: providers, session: session)
        self.persistenceController = persistence
        self.userRepository = UserRepository(container: persistence.container)
        self.mealSaver = SwiftDataMealSaver(container: persistence.container)
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                authService: authService,
                userRepository: userRepository,
                mealSaver: mealSaver
            )
            .environment(session)
            .modelContainer(persistenceController.container)
            .tint(Tokens.Palette.primary)
        }
    }
}
