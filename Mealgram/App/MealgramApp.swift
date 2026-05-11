import SwiftUI

@main
struct MealgramApp: App {
    @State private var session = AuthSession()
    private let authService: AuthService

    init() {
        let session = AuthSession()
        let providers: [any AuthProvider] = [
            AppleAuthProvider(),
            GoogleAuthProvider(),
            EmailAuthProvider(),
        ]
        self._session = State(initialValue: session)
        self.authService = AuthService(providers: providers, session: session)
    }

    var body: some Scene {
        WindowGroup {
            RootView(authService: authService)
                .environment(session)
                .tint(Tokens.Palette.primary)
        }
    }
}
