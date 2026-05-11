import Foundation
import OSLog
import Observation

/// Picks which top-level scene to show — auth, onboarding, or the main app.
/// Single source of truth so SwiftUI's `RootView` stays declarative.
@MainActor
@Observable
final class AppRouter {
    enum Phase: Equatable {
        case launching
        case anonymous
        case onboarding(authUser: AuthUser)
        case main(authUser: AuthUser)
    }

    private(set) var phase: Phase = .launching
    private let userRepository: UserRepository

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
    }

    /// Recomputes the route from the latest auth session state. Safe to call
    /// repeatedly — idempotent for the same `AuthSession.Phase`.
    func evaluate(authPhase: AuthSession.Phase) {
        switch authPhase {
        case .unknown:
            phase = .launching
        case .anonymous:
            phase = .anonymous
        case .authenticated(let authUser):
            do {
                let user = try userRepository.ensureUser(for: authUser)
                phase = user.isOnboarded ? .main(authUser: authUser) : .onboarding(authUser: authUser)
            } catch {
                Logger.ui.error("AppRouter ensureUser failed: \(String(describing: error))")
                phase = .anonymous
            }
        }
    }

    /// Called by the onboarding flow when the user finishes the last step.
    func markOnboarded() {
        guard case .onboarding(let authUser) = phase else { return }
        phase = .main(authUser: authUser)
    }
}
