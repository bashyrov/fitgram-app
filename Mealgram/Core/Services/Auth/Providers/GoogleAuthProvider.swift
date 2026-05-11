import Foundation
import OSLog

/// Stub provider — real implementation lands when we add the
/// `GoogleSignIn-iOS` SPM package and a Google OAuth Client ID arrives via
/// `AppConfig.googleOAuthClientID`. Until then this just fails fast so the
/// UI can surface the "not yet configured" message.
final class GoogleAuthProvider: AuthProvider {
    let kind: AuthProviderKind = .google

    func signIn() async throws -> AuthCredentials {
        guard AppConfig.isGoogleSignInConfigured else {
            throw AuthError.providerNotConfigured(.google)
        }
        // Real call goes here in Milestone 1.6 when the SDK is added.
        Logger.auth.fault("GoogleAuthProvider.signIn called but real SDK not yet wired up")
        throw AuthError.providerNotConfigured(.google)
    }

    func signOut() async {}
}
