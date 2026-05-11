import Foundation
import Observation

/// Top-level reactive snapshot of the auth state. Consumed by `RootView` to
/// pick the right scene (auth stack vs. main app).
@MainActor
@Observable
final class AuthSession {
    enum Phase: Equatable {
        case unknown
        case anonymous
        case authenticated(AuthUser)
    }

    private(set) var phase: Phase = .unknown
    /// Last surface-able error from a sign-in/sign-out attempt — cleared as
    /// soon as the user takes another action.
    private(set) var lastError: AuthError?
    private(set) var isWorking: Bool = false

    func update(phase: Phase) {
        self.phase = phase
        self.lastError = nil
    }

    func surface(error: AuthError) {
        self.lastError = error
    }

    func clearError() {
        self.lastError = nil
    }

    func setWorking(_ value: Bool) {
        self.isWorking = value
    }
}
