import Foundation
import OSLog

/// App Store guideline 5.1.1(v) requires apps that create accounts to also
/// offer in-app deletion. This service is the single entry point for that
/// flow — it deletes server-side data (Supabase) *first*, then nukes local
/// SwiftData stores and the keychain, then signs out.
///
/// Server side is stubbed until Supabase is wired up; local cleanup is real.
@MainActor
final class AccountDeletionService {
    private let authService: AuthService
    private let tokenStore: TokenStore
    private let persistence: PersistenceController?

    init(
        authService: AuthService,
        tokenStore: TokenStore = TokenStore(),
        persistence: PersistenceController? = nil
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.persistence = persistence
    }

    /// Permanently deletes the user's account. Idempotent — re-running on an
    /// anonymous device just clears whatever residue is left.
    func deleteAccount() async throws {
        Logger.auth.warning("Account deletion initiated")

        try await deleteServerData()
        try clearLocalStores()
        await authService.signOut()

        Logger.auth.warning("Account deletion finished")
    }

    /// Wipes Supabase-side data. Real implementation calls the
    /// `/api/v1/account` DELETE Edge Function once we have a Supabase client.
    private func deleteServerData() async throws {
        guard AppConfig.isSupabaseConfigured else {
            Logger.auth.notice("Skipping server-side deletion: Supabase not configured")
            return
        }
        // TODO(Milestone 1.6): call Edge Function once Supabase client lands.
    }

    private func clearLocalStores() throws {
        try tokenStore.clear()
        try persistence?.wipeAllData()
    }
}
