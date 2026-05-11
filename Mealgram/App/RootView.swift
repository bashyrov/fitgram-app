import SwiftUI

/// Top-level routing. Watches the shared `AuthSession` and shows the auth
/// stack when anonymous, a tiny "you're signed in" placeholder when
/// authenticated (replaced with the main TabView in Milestone 1.7), or a
/// splash while we resolve the persisted session on first launch.
struct RootView: View {
    @Environment(AuthSession.self) private var session
    let authService: AuthService

    var body: some View {
        Group {
            switch session.phase {
            case .unknown:
                splash
            case .anonymous:
                AuthView(authService: authService)
                    .transition(.opacity)
            case .authenticated(let user):
                AuthenticatedPlaceholder(user: user) {
                    Task { await authService.signOut() }
                }
                .transition(.opacity)
            }
        }
        .animation(Tokens.Motion.gentle, value: session.phase)
        .task {
            if case .unknown = session.phase {
                await authService.restoreSession()
            }
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
}

/// Placeholder shown right after sign-in. Replaced with `TabView` in
/// Milestone 1.7 (Today screen).
private struct AuthenticatedPlaceholder: View {
    let user: AuthUser
    let onSignOut: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background
                .ignoresSafeArea()
            VStack(spacing: Tokens.Space.xl) {
                Spacer()
                EmptyState(
                    symbol: "checkmark.seal.fill",
                    title: "Cześć!",
                    message: "Jesteś zalogowany przez \(user.provider.displayName). Główny ekran wkrótce.",
                    action: nil
                )
                Spacer()
                SecondaryButton(title: "Wyloguj", systemImage: "rectangle.portrait.and.arrow.right") {
                    onSignOut()
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
        }
    }
}
