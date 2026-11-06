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
    /// Called with the account id each time someone signs in, before the
    /// UI reroutes. The composition root uses it to claim legacy rows.
    @ObservationIgnored var onSignedIn: ((String) -> Void)?

    func update(phase: Phase) {
        if case .authenticated(let user) = phase {
            AccountScope.activate(user.id)
            onSignedIn?(user.id)
        } else {
            AccountScope.activate(nil)
        }
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

    /// Convenience for services that only need the auth identity string
    /// (e.g. `UserProfileService`) so they don't have to do their own
    /// phase pattern match every call.
    var currentRemoteID: String? {
        if case .authenticated(let user) = phase { return user.id }
        return nil
    }
}
