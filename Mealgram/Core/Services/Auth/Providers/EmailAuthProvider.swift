import Foundation
import OSLog

/// Two-phase email sign-in via Supabase magic links.
///
/// 1. `requestMagicLink(email:)` — POSTs to `/auth/v1/otp` so Supabase emails
///    the user a one-tap link that opens our app via the `mealgram://`
///    URL scheme.
/// 2. `complete(callbackURL:)` — runs when the user taps that link and iOS
///    routes it back through `MealgramApp`'s `onOpenURL`. The URL carries
///    `access_token` / `refresh_token` / `expires_in` in its fragment.
///
/// The generic `AuthProvider.signIn()` is unused for email — the UI drives
/// the two-phase flow directly via `EmailAuthService` (see below).
@MainActor
final class EmailAuthProvider: AuthProvider {
    let kind: AuthProviderKind = .email

    func signIn() async throws -> AuthCredentials {
        // Email isn't a one-shot — the UI calls `requestMagicLink` directly.
        // Throwing here keeps the generic AuthService.signIn(with:) path
        // honest if someone accidentally invokes it.
        throw AuthError.providerNotConfigured(.email)
    }

    func signOut() async {}

    // MARK: - Phase 1: request the magic link

    struct MagicLinkRequestError: LocalizedError {
        let status: Int
        let message: String
        var errorDescription: String? { message }
    }

    func requestMagicLink(
        email: String,
        session: URLSession = .shared
    ) async throws {
        guard let supabaseURL = AppConfig.supabaseURL,
            let anonKey = AppConfig.supabaseAnonKey
        else {
            throw AuthError.providerNotConfigured(.email)
        }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            throw MagicLinkRequestError(status: 400, message: "Wpisz poprawny adres email.")
        }

        var request = URLRequest(url: supabaseURL.appending(path: "auth/v1/otp"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")

        let payload: [String: Any] = [
            "email": trimmed,
            "create_user": true,
            "options": [
                "email_redirect_to": "mealgram://auth/callback"
            ],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.auth.error("Magic-link request failed: \(status) \(body, privacy: .public)")
            throw MagicLinkRequestError(
                status: status, message: "Nie udało się wysłać linku. Spróbuj ponownie za chwilę.")
        }
        Logger.auth.notice("Magic link sent to \(trimmed, privacy: .private(mask: .hash))")
    }

    // MARK: - Phase 2: complete sign-in from callback URL

    func complete(callbackURL: URL) throws -> AuthCredentials {
        // Supabase puts tokens in the URL fragment after `#`.
        // Example: mealgram://auth/callback#access_token=eyJ...&refresh_token=...&expires_in=3600
        let fragment = callbackURL.fragment ?? ""
        guard !fragment.isEmpty else {
            throw AuthError.invalidCredential
        }
        let pairs = fragment.split(separator: "&").reduce(into: [String: String]()) { acc, pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0])
                let value = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                acc[key] = value
            }
        }
        guard let access = pairs["access_token"], !access.isEmpty else {
            throw AuthError.invalidCredential
        }
        let refresh = pairs["refresh_token"]
        let expiresIn = pairs["expires_in"].flatMap(Double.init).map { Date().addingTimeInterval($0) }

        // Decode the JWT to pull out the Supabase user id (sub).
        let userID = Self.extractSubject(fromJWT: access) ?? UUID().uuidString
        return AuthCredentials(
            userID: userID,
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiresIn,
            provider: .email
        )
    }

    private static func extractSubject(fromJWT token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        // base64url → base64 padding
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String
        else { return nil }
        return sub
    }
}
