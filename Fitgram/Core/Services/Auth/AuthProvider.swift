import Foundation

/// What every concrete auth flow has to deliver. Implementations live under
/// `Providers/`. They never touch the keychain themselves — that's
/// `AuthService`'s job, so providers stay easy to test in isolation.
protocol AuthProvider: Sendable {
    var kind: AuthProviderKind { get }
    func signIn() async throws -> AuthCredentials
    /// Best-effort: revokes provider-side tokens (e.g. Apple credential
    /// revocation) — failures are logged, not surfaced, because local sign-out
    /// must succeed regardless.
    func signOut() async
}
