import Foundation
import OSLog
import WidgetKit

/// App Store guideline 5.1.1(v) requires apps that create accounts to also
/// offer in-app deletion. This service is the single entry point for that
/// flow, in this order:
/// 1. Sign in with Apple accounts confirm with Apple once more; the fresh
///    authorization code lets the Worker revoke the app's Apple tokens.
/// 2. The Worker deletes its rows (subscription status, AI usage).
/// 3. The Supabase `account` Edge Function deletes profile / social rows and
///    the auth user.
/// 4. This account's local rows, photos and settings are deleted (other
///    accounts on the iPhone are kept), caches, notifications and the
///    keychain are cleared and the user is signed out.
///
/// Server steps run only when the Worker / Supabase are configured; local
/// cleanup is always real so the device never keeps stale personal data.
@MainActor
final class AccountDeletionService {
    private let authService: AuthService
    private let tokenStore: TokenStore
    private let persistence: PersistenceController?
    private let defaults: UserDefaults
    private let notificationService: NotificationService
    private let spotlightIndexer: any RecipeSpotlightIndexing
    private let session: URLSession

    init(
        authService: AuthService,
        tokenStore: TokenStore = TokenStore(),
        persistence: PersistenceController? = nil,
        defaults: UserDefaults = .standard,
        notificationService: NotificationService = NotificationService(),
        spotlightIndexer: any RecipeSpotlightIndexing = RecipeSpotlightIndexer(),
        session: URLSession = .shared
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.persistence = persistence
        self.defaults = defaults
        self.notificationService = notificationService
        self.spotlightIndexer = spotlightIndexer
        self.session = session
    }

    /// Permanently deletes the user's account. Idempotent — re-running on an
    /// anonymous device just clears whatever residue is left.
    func deleteAccount() async throws {
        Logger.auth.warning("Account deletion initiated")

        let appleCode = try await authService.appleAuthorizationCodeForAccountDeletion()
        try await deleteWorkerData(appleAuthorizationCode: appleCode)
        try await deleteServerData()
        await clearLocalStores()
        await authService.signOut()

        Logger.auth.warning("Account deletion finished")
    }

    /// Deletes the Worker's rows for this user and, with an Apple code,
    /// revokes the Apple tokens (`DELETE /api/v1/account`).
    private func deleteWorkerData(appleAuthorizationCode: String?) async throws {
        guard let baseURL = AppConfig.workerBaseURL else {
            Logger.auth.notice("Skipping Worker deletion: Worker not configured")
            return
        }
        guard let token = try tokenStore.accessToken, !token.isEmpty else {
            Logger.auth.notice("Skipping Worker deletion: user is already signed out")
            return
        }

        var request = URLRequest(url: baseURL.appending(path: "api/v1/account"))
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let appleAuthorizationCode {
            request.httpBody = try JSONEncoder().encode(["apple_authorization_code": appleAuthorizationCode])
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.auth.error("Worker account deletion failed: \(http.statusCode) \(body, privacy: .public)")
            throw AuthError.unknown(underlying: L("Nie udało się usunąć danych z serwera. Spróbuj ponownie."))
        }
        Logger.auth.notice(
            "Worker account data deleted: \(String(data: data, encoding: .utf8) ?? "", privacy: .public)")
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

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.auth.error("Server-side deletion failed: \(http.statusCode) \(body, privacy: .public)")
            throw AuthError.unknown(underlying: L("Nie udało się usunąć danych z serwera. Spróbuj ponownie."))
        }
    }

    /// Removes only the deleted account's data. Other accounts that signed
    /// in on this iPhone keep their meals, recipes, photos and settings.
    private func clearLocalStores() async {
        let userID = (try? tokenStore.userID).flatMap { $0 } ?? AccountScope.currentUserID
        if let persistence, !userID.isEmpty {
            do {
                try AccountSwitcher.deleteAccountData(
                    userID,
                    container: persistence.container,
                    defaults: defaults,
                    photoStore: try? MealPhotoStore(),
                    avatarDirectory: AvatarStore().directory,
                    syncState: CloudSyncStateStore()
                )
            } catch {
                Logger.persistence.error("Account local data deletion failed: \(String(describing: error))")
            }
        }
        do {
            try tokenStore.clear()
        } catch {
            Logger.auth.error("Account token clear failed: \(String(describing: error))")
        }
        // Spotlight and the widget show the signed-in account only; the next
        // sign-in fills them again for that account.
        spotlightIndexer.removeAll()
        WidgetSnapshotStore.shared.clear()
        await notificationService.clearAllFitgramNotifications()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
