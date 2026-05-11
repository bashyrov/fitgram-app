import SwiftData
import SwiftUI

@main
struct MealgramApp: App {
    @State private var session: AuthSession
    private let authService: AuthService
    private let persistenceController: PersistenceController

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
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService)
                .environment(session)
                .modelContainer(persistenceController.container)
                .tint(Tokens.Palette.primary)
        }
    }
}
