import Foundation
import OSLog
import WidgetKit

/// App Store guideline 5.1.1(v) requires apps that create accounts to also
/// offer in-app deletion. This service is the single entry point for that
/// flow — it deletes server-side data (Supabase) *first*, then clears local
/// account-owned SwiftData rows, files, caches, notifications, and keychain,
/// then signs out.
///
/// Server-side deletion goes through the Supabase Edge Function when the
/// production Supabase URL + anon key are configured; local cleanup is always
/// real so the device never keeps stale personal data.
@MainActor
final class AccountDeletionService {
    private let authService: AuthService
    private let tokenStore: TokenStore
    private let persistence: PersistenceController?
    private let defaults: UserDefaults
    private let appGroupDefaults: UserDefaults?
    private let notificationService: NotificationService
    private let spotlightIndexer: any RecipeSpotlightIndexing

    init(
        authService: AuthService,
        tokenStore: TokenStore = TokenStore(),
        persistence: PersistenceController? = nil,
        defaults: UserDefaults = .standard,
        appGroupDefaults: UserDefaults? = UserDefaults(suiteName: WidgetSnapshotStore.appGroupID),
        notificationService: NotificationService = NotificationService(),
        spotlightIndexer: any RecipeSpotlightIndexing = RecipeSpotlightIndexer()
    ) {
        self.authService = authService
        self.tokenStore = tokenStore
        self.persistence = persistence
        self.defaults = defaults
        self.appGroupDefaults = appGroupDefaults
        self.notificationService = notificationService
        self.spotlightIndexer = spotlightIndexer
    }

    /// Permanently deletes the user's account. Idempotent — re-running on an
    /// anonymous device just clears whatever residue is left.
    func deleteAccount() async throws {
        Logger.auth.warning("Account deletion initiated")

        try await deleteServerData()
        await clearLocalStores()
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

    private func clearLocalStores() async {
        do {
            try persistence?.wipeAccountData()
        } catch {
            Logger.persistence.error("Account local SwiftData wipe failed: \(String(describing: error))")
        }
        do {
            try tokenStore.clear()
        } catch {
            Logger.auth.error("Account token clear failed: \(String(describing: error))")
        }
        (try? MealPhotoStore())?.removeAll()
        AvatarStore().removeAll()
        spotlightIndexer.removeAll()
        WidgetSnapshotStore.shared.clear()
        clearAccountDefaults(defaults)
        if let appGroupDefaults {
            clearAccountDefaults(appGroupDefaults)
        }
        await notificationService.clearAllFitgramNotifications()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearAccountDefaults(_ defaults: UserDefaults) {
        let preservedKeys = Set([
            "app.language",
            "AppleLanguages",
            "preferences.theme",
            AppAccentPalette.storageKey,
            "preferences.appIcon",
            "preferences.didMigrateDefaultAccentToCitrus",
        ])
        let prefixes = [
            "usage.",
            "water.",
            "weight.",
            "privacy.",
            "coach.",
            "cultural.",
            "debug.",
            "whatsnew.",
            "preferences.friend.",
            "preferences.morningReminder",
            "preferences.streakRisk",
            "preferences.eveningReminder",
            "preferences.goalWeight",
        ]
        for key in defaults.dictionaryRepresentation().keys {
            guard !preservedKeys.contains(key),
                prefixes.contains(where: { key.hasPrefix($0) })
            else { continue }
            defaults.removeObject(forKey: key)
        }
    }
}
