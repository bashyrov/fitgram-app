import Foundation
import OSLog

/// App Store guideline 5.1.1(v) requires apps that create accounts to also
/// offer in-app deletion. This service is the single entry point for that
/// flow — it deletes server-side data (Supabase) *first*, then nukes local
/// SwiftData stores and the keychain, then signs out.
///
/// Server-side deletion goes through the Supabase Edge Function when the
/// production Supabase URL + anon key are configured; local cleanup is always
/// real so the device never keeps stale personal data.
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

    /// Wipes Supabase-side data via the `account` Edge Function. The function
    /// owns table-by-table cascading so the app never ships admin delete logic.
    private func deleteServerData() async throws {
        guard let supabaseURL = AppConfig.supabaseURL,
            let anonKey = AppConfig.supabaseAnonKey
        else {
            Logger.auth.notice("Skipping server-side deletion: Supabase not configured")
            return
        }
        guard let token = try tokenStore.accessToken, !token.isEmpty else {
            Logger.auth.notice("Skipping server-side deletion: user is already signed out")
            return
        }

        let url = supabaseURL.appending(path: "functions/v1/account")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.auth.error("Server-side deletion failed: \(http.statusCode) \(body, privacy: .public)")
            throw AuthError.unknown(underlying: L("Nie udało się usunąć danych z serwera. Spróbuj ponownie."))
        }
    }

    private func clearLocalStores() throws {
        try tokenStore.clear()
        try persistence?.wipeAllData()
    }
}
