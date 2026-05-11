import SwiftUI

/// Top-level routing. Reacts to the shared `AuthSession` via `AppRouter`
/// to show one of: launch splash, auth stack, onboarding, or main app
/// (placeholder until Milestone 1.7 lands the Today screen).
struct RootView: View {
    @Environment(AuthSession.self) private var session
    let authService: AuthService
    let userRepository: UserRepository
    @State private var router: AppRouter
    @State private var onboardingFlow: OnboardingFlow?

    init(authService: AuthService, userRepository: UserRepository) {
        self.authService = authService
        self.userRepository = userRepository
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
                AuthenticatedPlaceholder(user: authUser) {
                    Task { await authService.signOut() }
                }
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
        if let flow = onboardingFlow, flowMatches(authUser) {
            OnboardingView(flow: flow)
        } else {
            OnboardingView(flow: freshFlow(for: authUser))
        }
    }

    /// Stable identity key so SwiftUI's `.animation(value:)` can detect
    /// transitions across associated-value-bearing enum cases.
    private var phaseKey: String {
        switch router.phase {
        case .launching: return "launching"
        case .anonymous: return "anonymous"
        case .onboarding(let user): return "onboarding-\(user.id)"
        case .main(let user): return "main-\(user.id)"
        }
    }

    private func flowMatches(_ authUser: AuthUser) -> Bool {
        // Currently a single onboarding flow lives per session; the check is
        // here to make future multi-user testing trivial.
        true
    }

    private func freshFlow(for authUser: AuthUser) -> OnboardingFlow {
        let flow = OnboardingFlow(
            authUser: authUser,
            userRepository: userRepository,
            onFinished: { [router] outcome in
                if outcome == .completed { router.markOnboarded() }
            }
        )
        DispatchQueue.main.async { self.onboardingFlow = flow }
        return flow
    }
}

/// Placeholder shown right after onboarding. Replaced with `TabView` in
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
                    title: "Wszystko gotowe!",
                    message: "Twój profil został zapisany. Główny ekran wkrótce.",
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
