import Foundation

/// Cross-cutting hook applied to every outgoing request. Examples: auth
/// header injection, debug logging, custom tracing IDs.
protocol RequestInterceptor: Sendable {
    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest
}
