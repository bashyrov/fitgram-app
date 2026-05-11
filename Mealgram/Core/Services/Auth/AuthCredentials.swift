import Foundation

/// Which provider produced a given session. Persisted in `TokenStore` so we
/// know how to refresh / revoke later.
enum AuthProviderKind: String, Sendable, CaseIterable {
    case apple
    case google
    case email

    var displayName: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .email: return "e-mail"
        }
    }
}

/// What the app needs to keep around after a successful sign-in. The
/// `accessToken` is always the Supabase JWT — provider-specific tokens
/// (Apple identity token, Google id_token) are exchanged for it server-side
/// and not retained on device.
struct AuthCredentials: Equatable, Sendable {
    let userID: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
    let provider: AuthProviderKind
}

/// Lightweight user identity for the UI layer. Populated from whatever
/// the auth provider chose to share (Apple gives us name only on the very
/// first sign-in, so we cache it).
struct AuthUser: Equatable, Sendable, Identifiable {
    let id: String
    let email: String?
    let displayName: String?
    let provider: AuthProviderKind
}
