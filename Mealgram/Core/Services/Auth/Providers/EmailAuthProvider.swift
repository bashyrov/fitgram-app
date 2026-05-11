import Foundation
import OSLog

/// Stub provider — magic-link email auth uses Supabase. Until the
/// `supabase-swift` SPM package is wired and `AppConfig` carries the
/// project URL + anon key, this throws so the UI surfaces a useful message.
///
/// The real flow has two phases: request OTP / magic link, then verify on
/// return. We'll model that as `requestLink(email:)` + `verify(token:)` on a
/// separate protocol — the generic `AuthProvider.signIn()` only handles the
/// terminal step. For now we just early-fail.
final class EmailAuthProvider: AuthProvider {
    let kind: AuthProviderKind = .email

    func signIn() async throws -> AuthCredentials {
        guard AppConfig.isSupabaseConfigured else {
            throw AuthError.providerNotConfigured(.email)
        }
        Logger.auth.fault("EmailAuthProvider.signIn called but real Supabase client not yet wired up")
        throw AuthError.providerNotConfigured(.email)
    }

    func signOut() async {}
}
