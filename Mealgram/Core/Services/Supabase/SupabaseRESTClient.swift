import Foundation

struct SupabaseRESTClient: Sendable {
    enum SupabaseError: Error, Sendable {
        case notConfigured
        case unauthorized
        case invalidResponse
        case http(status: Int, body: String)
    }

    let baseURL: URL
    let anonKey: String
    let tokenStore: TokenStore
    let session: URLSession
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init?(
        baseURL: URL? = AppConfig.supabaseURL,
        anonKey: String? = AppConfig.supabaseAnonKey,
        tokenStore: TokenStore = TokenStore(),
        session: URLSession = .shared,
        decoder: JSONDecoder = .mealgram,
        encoder: JSONEncoder = .mealgram
    ) {
        guard let baseURL, let anonKey, !anonKey.isEmpty else { return nil }
        self.baseURL = baseURL
        self.anonKey = anonKey
        self.tokenStore = tokenStore
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
    }

    func request<Response: Decodable & Sendable>(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        prefer: String? = nil,
        expecting: Response.Type = Response.self
    ) async throws -> Response {
        let data = try await rawRequest(
            path: path,
            method: method,
            query: query,
            body: body,
            prefer: prefer
        )
        if data.isEmpty, let empty = EmptyResponse() as? Response {
            return empty
        }
        return try decoder.decode(Response.self, from: data)
    }

    func request(
        path: String,
        method: HTTPMethod = .get,
        query: [URLQueryItem] = [],
        body: (any Encodable)? = nil,
        prefer: String? = nil
    ) async throws {
        _ = try await rawRequest(
            path: path,
            method: method,
            query: query,
            body: body,
            prefer: prefer
        )
    }

    private func rawRequest(
        path: String,
        method: HTTPMethod,
        query: [URLQueryItem],
        body: (any Encodable)?,
        prefer: String?
    ) async throws -> Data {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseError.notConfigured
        }
        let cleanPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        components.path = components.path.appending("/rest/v1/\(cleanPath)")
        components.queryItems = query.isEmpty ? nil : query
        guard let url = components.url else { throw SupabaseError.notConfigured }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer {
            request.setValue(prefer, forHTTPHeaderField: "Prefer")
        }
        guard let token = try tokenStore.accessToken, !token.isEmpty else {
            throw SupabaseError.unauthorized
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try encoder.encode(AnyEncodable(body))
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw SupabaseError.http(status: http.statusCode, body: body)
        }
        return data
    }
}

private struct AnyEncodable: Encodable {
    let encodeClosure: (Encoder) throws -> Void

    init(_ wrapped: any Encodable) {
        self.encodeClosure = wrapped.encode(to:)
    }

    func encode(to encoder: Encoder) throws {
        try encodeClosure(encoder)
    }
}
