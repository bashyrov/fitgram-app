import Foundation

struct SupabaseAuthExchange: Sendable {
    enum ExchangeError: Error, Sendable {
        case notConfigured
        case invalidResponse
        case http(status: Int, body: String)
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = .fitgram) {
        self.session = session
        self.decoder = decoder
    }

    func exchangeGoogleIDToken(_ idToken: String) async throws -> AuthCredentials {
        try await exchangeIDToken(idToken, provider: .google, nonce: nil)
    }

    /// Sign in with Apple: `rawNonce` is the value whose SHA-256 was set on
    /// the Apple request; Supabase re-hashes it to check the token's nonce.
    func exchangeAppleIDToken(_ idToken: String, rawNonce: String) async throws -> AuthCredentials {
        try await exchangeIDToken(idToken, provider: .apple, nonce: rawNonce)
    }

    /// Trades a provider ID token for a Supabase session (grant_type=id_token),
    /// so the Worker and Supabase both accept the resulting access token.
    private func exchangeIDToken(
        _ idToken: String,
        provider: AuthProviderKind,
        nonce: String?
    ) async throws -> AuthCredentials {
        guard let supabaseURL = AppConfig.supabaseURL,
            let anonKey = AppConfig.supabaseAnonKey
        else {
            throw ExchangeError.notConfigured
        }

        var components = URLComponents(
            url: supabaseURL.appending(path: "auth/v1/token"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "id_token")]
        guard let url = components?.url else { throw ExchangeError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            IDTokenPayload(provider: provider.rawValue, idToken: idToken, nonce: nonce)
        )

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ExchangeError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ExchangeError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }
        let payload = try decoder.decode(SupabaseTokenResponse.self, from: data)
        return AuthCredentials(
            userID: payload.user.id,
            accessToken: payload.accessToken,
            refreshToken: payload.refreshToken,
            expiresAt: payload.expiresIn.map { Date().addingTimeInterval(Double($0)) },
            provider: provider
        )
    }
}

private struct IDTokenPayload: Encodable {
    let provider: String
    let idToken: String
    let nonce: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case idToken = "id_token"
        case nonce
    }
}

private struct SupabaseTokenResponse: Decodable {
    struct User: Decodable {
        let id: String
    }

    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int?
    let user: User
}
