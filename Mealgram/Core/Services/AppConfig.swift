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
