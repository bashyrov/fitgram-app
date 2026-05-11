import Foundation

/// Describes a single HTTP call. Concrete features build these — the API
/// client knows nothing about specific routes.
struct Endpoint: Sendable {
    enum Body: Sendable {
        case empty
        case json(Data)
        /// Pre-built multipart payload (image upload). Caller supplies the
        /// boundary so the Content-Type header matches.
        case multipart(boundary: String, data: Data)
    }

    var path: String
    var method: HTTPMethod = .get
    var query: [URLQueryItem] = []
    var headers: [String: String] = [:]
    var body: Body = .empty
    var requiresAuth: Bool = true
    /// Optional per-endpoint timeout override (default uses URLSessionConfiguration).
    var timeout: TimeInterval?
}

extension Endpoint {
    /// JSON-encodes an Encodable payload — small enough that callers don't
    /// have to wire up JSONEncoder themselves.
    static func json<Payload: Encodable>(
        path: String,
        method: HTTPMethod = .post,
        payload: Payload,
        encoder: JSONEncoder = .mealgram,
        requiresAuth: Bool = true
    ) throws -> Endpoint {
        let data = try encoder.encode(payload)
        return Endpoint(
            path: path,
            method: method,
            headers: ["Content-Type": "application/json"],
            body: .json(data),
            requiresAuth: requiresAuth
        )
    }
}

extension JSONEncoder {
    /// Project-wide default — snake_case keys + ISO8601 dates, to match the
    /// Cloudflare Worker / Supabase Edge Function conventions.
    static var mealgram: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }
}

extension JSONDecoder {
    static var mealgram: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }
}
