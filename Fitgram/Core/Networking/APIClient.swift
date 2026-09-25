import Foundation

/// What feature modules call. Keep this surface minimal — extras (multipart,
/// streaming) get added when a milestone actually needs them.
protocol APIClient: Sendable {
    /// Sends an endpoint and decodes the response body into `Response`.
    /// Throws `APIError`.
    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        expecting: Response.Type
    ) async throws -> Response

    /// Convenience for endpoints we don't care about a response body for.
    func send(_ endpoint: Endpoint) async throws
}

/// Empty stand-in `Decodable` for the void-response variant. The default
/// implementation pipes through `send(_:expecting:)` so concrete clients
/// only have to implement one method.
struct EmptyResponse: Decodable, Sendable {}

extension APIClient {
    func send(_ endpoint: Endpoint) async throws {
        _ = try await send(endpoint, expecting: EmptyResponse.self)
    }
}
