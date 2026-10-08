import Foundation

/// Adds `Authorization: Bearer <jwt>` to endpoints that require it. The
/// token comes from `AccessTokenProvider`, which refreshes it before the
/// ~1 h Supabase expiry so requests don't start failing with 401.
struct AuthInterceptor: RequestInterceptor {
    private let tokens: AccessTokenProvider

    init(tokens: AccessTokenProvider = .shared) {
        self.tokens = tokens
    }

    /// Reads from a specific store (tests, isolated keychains).
    init(tokenStore: TokenStore) {
        self.tokens = AccessTokenProvider(tokenStore: tokenStore)
    }

    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        guard endpoint.requiresAuth else { return request }
        guard let token = try? await tokens.validAccessToken(), !token.isEmpty else {
            throw APIError.unauthorized
        }
        var adapted = request
        adapted.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return adapted
    }
}
