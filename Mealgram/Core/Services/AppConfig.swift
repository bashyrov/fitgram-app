import Foundation

/// Reads build-time configuration from the bundle's Info.plist (which is
/// stamped from `.env` via xcconfig in later milestones). Falls back to safe
/// empty strings during development so the app boots even when keys aren't
/// wired up yet — feature code should call `requireXyz()` accessors to fail
/// loudly at the point of use.
enum AppConfig {
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "app.mealgram.ios"
    }

    static var supabaseURL: URL? {
        urlValue(for: "SUPABASE_URL")
    }

    static var supabaseAnonKey: String? {
        stringValue(for: "SUPABASE_ANON_KEY")
    }

    static var googleOAuthClientID: String? {
        stringValue(for: "GOOGLE_OAUTH_CLIENT_ID")
    }

    static var workerBaseURL: URL? {
        urlValue(for: "WORKER_BASE_URL")
    }

    static var isSupabaseConfigured: Bool {
        supabaseURL != nil && supabaseAnonKey != nil
    }

    static var isGoogleSignInConfigured: Bool {
        googleOAuthClientID != nil
    }

    /// Master switch for the Premium subscription gating. When `false`
    /// (the default for v1), every feature is unlocked for every user —
    /// paywall is hidden, premium banners suppressed, and the in-memory
    /// `SubscriptionService` reports the user as already-premium so all
    /// `isPremium`-gated UI behaves as if the user paid. Flip to `true`
    /// (via the `IS_PAYMENTS_ENABLED` build setting / Info.plist key)
    /// once banking + IAP products are live in App Store Connect.
    static var isPaymentsEnabled: Bool {
        boolValue(for: "IS_PAYMENTS_ENABLED") ?? false
    }

    private static func boolValue(for key: String) -> Bool? {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: key) else { return nil }
        if let bool = raw as? Bool { return bool }
        if let str = raw as? String {
            let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if trimmed.isEmpty { return nil }
            return ["1", "true", "yes"].contains(trimmed)
        }
        return nil
    }

    // MARK: Helpers

    private static func stringValue(for key: String) -> String? {
        let raw = Bundle.main.object(forInfoDictionaryKey: key) as? String
        guard let raw, !raw.isEmpty else { return nil }
        return raw
    }

    private static func urlValue(for key: String) -> URL? {
        guard let raw = stringValue(for: key) else { return nil }
        return URL(string: raw)
    }
}
