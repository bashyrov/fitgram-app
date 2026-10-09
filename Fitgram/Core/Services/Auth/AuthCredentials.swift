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

/// Reads claims from a JWT payload without verifying it. Only for display
/// data (the account email) — never for authorization decisions.
enum JWTClaims {
    static func string(_ key: String, in token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let value = json[key] as? String, !value.isEmpty
        else { return nil }
        return value
    }

    /// Email in a Supabase access token or an Apple identity token. Present
    /// on every sign-in, unlike Apple's credential.email (first sign-in only).
    static func email(in token: String) -> String? {
        string("email", in: token)
    }
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
