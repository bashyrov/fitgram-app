import Foundation
import OSLog

/// Hands out a Supabase access token that is still valid, refreshing it with
/// the stored refresh token shortly before it expires. Supabase access tokens
/// live ~1 hour; without this every Worker / Supabase call started failing
/// with 401 an hour after sign-in (AI scans, coach, sync all "stopped working").
/// Concurrent callers share one in-flight refresh.
actor AccessTokenProvider {
    static let shared = AccessTokenProvider()

    enum ProviderError: Error {
        case signedOut
    }

    /// Refresh this long before `exp` so a request never departs with a token
    /// that expires mid-flight.
    private let leeway: TimeInterval = 120
    private let tokenStore: TokenStore
    private let exchange: SupabaseAuthExchange
    private var inFlight: Task<String, any Error>?

    init(tokenStore: TokenStore = TokenStore(), exchange: SupabaseAuthExchange = SupabaseAuthExchange()) {
        self.tokenStore = tokenStore
        self.exchange = exchange
    }

    func validAccessToken() async throws -> String {
        guard let token = try tokenStore.accessToken, !token.isEmpty else {
            throw ProviderError.signedOut
        }
        // Unknown expiry (non-JWT) — use as is rather than refreshing blindly.
        guard let expiry = Self.expiry(ofJWT: token) else { return token }
        if expiry.timeIntervalSinceNow > leeway { return token }
        return try await refresh()
    }

    /// Forces a refresh, e.g. after the server rejected the token.
    func refresh() async throws -> String {
        if let inFlight { return try await inFlight.value }
        let task = Task { () throws -> String in
            guard let refreshToken = try tokenStore.refreshToken, !refreshToken.isEmpty else {
                throw ProviderError.signedOut
            }
            let provider = (try tokenStore.providerKind).flatMap(AuthProviderKind.init(rawValue:)) ?? .email
            let credentials = try await exchange.refresh(refreshToken: refreshToken, provider: provider)
            try tokenStore.save(session: credentials)
            Logger.auth.notice("Access token refreshed")
            return credentials.accessToken
        }
        inFlight = task
        defer { inFlight = nil }
        return try await task.value
    }

    /// Reads `exp` from a JWT payload without verifying it — only used to
    /// decide when to refresh; the server still verifies every token.
    static func expiry(ofJWT token: String) -> Date? {
        let parts = token.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
        guard let data = Data(base64Encoded: base64),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let exp = object["exp"] as? Double
        else { return nil }
        return Date(timeIntervalSince1970: exp)
    }
}
