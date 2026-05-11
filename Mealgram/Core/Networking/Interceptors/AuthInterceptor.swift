import Foundation

/// Adds `Authorization: Bearer <jwt>` to endpoints that require it. Pulls
/// from `TokenStore` so live token rotation propagates automatically.
struct AuthInterceptor: RequestInterceptor {
    private let tokenStore: TokenStore

    init(tokenStore: TokenStore = TokenStore()) {
        self.tokenStore = tokenStore
    }

    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        guard endpoint.requiresAuth else { return request }
        guard let token = try tokenStore.accessToken, !token.isEmpty else {
            throw APIError.unauthorized
        }
        var adapted = request
        adapted.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return adapted
    }
}
