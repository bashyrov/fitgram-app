import Foundation
import OSLog

/// `URLSession`-based `APIClient`. Composes interceptors + retry policy.
/// Stateless aside from its dependencies — safe to instantiate per-feature
/// or share via dependency injection.
struct URLSessionAPIClient: APIClient {
    let session: URLSession
    let baseURL: URL
    let interceptors: [any RequestInterceptor]
    let retryPolicy: RetryPolicy
    let decoder: JSONDecoder

    init(
        session: URLSession = .shared,
        baseURL: URL,
        interceptors: [any RequestInterceptor] = [],
        retryPolicy: RetryPolicy = .default,
        decoder: JSONDecoder = .mealgram
    ) {
        self.session = session
        self.baseURL = baseURL
        self.interceptors = interceptors
        self.retryPolicy = retryPolicy
        self.decoder = decoder
    }

    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        expecting: Response.Type
    ) async throws -> Response {
        let data = try await sendRaw(endpoint)
        if let empty = EmptyResponse() as? Response, data.isEmpty {
            // Skip a no-op decode for endpoints with empty bodies.
            return empty
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            Logger.networking.error("Decode failed: \(String(describing: error))")
            throw APIError.decoding(reason: String(describing: error))
        }
    }

    // MARK: - Core

    private func sendRaw(_ endpoint: Endpoint) async throws -> Data {
        var lastError: APIError = .unknown(reason: "no attempt run")
        for attempt in 1...max(1, retryPolicy.maxAttempts) {
            do {
                return try await performOnce(endpoint)
            } catch let error as APIError {
                lastError = error
                guard error.isRetryable, attempt < retryPolicy.maxAttempts else { throw error }
                let delay = retryPolicy.delay(forAttempt: attempt)
                let method = endpoint.method.rawValue
                let path = endpoint.path
                let nextAttempt = attempt + 1
                Logger.networking.notice(
                    """
                    Retrying \(method, privacy: .public) \(path, privacy: .public) \
                    attempt \(nextAttempt) in \(delay, format: .fixed(precision: 2))s
                    """
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        throw lastError
    }

    private func performOnce(_ endpoint: Endpoint) async throws -> Data {
        var request = try buildRequest(endpoint)
        for interceptor in interceptors {
            request = try await interceptor.adapt(request, for: endpoint)
        }

        let response: (data: Data, response: URLResponse)
        do {
            response = try await session.data(for: request)
        } catch let urlError as URLError {
            throw APIError.transport(urlError.code)
        } catch {
            throw APIError.unknown(reason: error.localizedDescription)
        }

        guard let http = response.response as? HTTPURLResponse else {
            throw APIError.unknown(reason: "Non-HTTP response")
        }

        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, body: response.data)
        }

        return response.data
    }

    private func buildRequest(_ endpoint: Endpoint) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: true) else {
            throw APIError.notConfigured
        }
        let combinedPath =
            components.path.hasSuffix("/")
            ? components.path + endpoint.path.trimmingPrefix("/")
            : components.path + (endpoint.path.hasPrefix("/") ? endpoint.path : "/" + endpoint.path)
        components.path = combinedPath
        if !endpoint.query.isEmpty {
            components.queryItems = endpoint.query
        }

        guard let url = components.url else {
            throw APIError.notConfigured
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        endpoint.headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        if let timeout = endpoint.timeout {
            request.timeoutInterval = timeout
        }

        switch endpoint.body {
        case .empty:
            break
        case .json(let data):
            request.httpBody = data
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        case .multipart(let boundary, let data):
            request.httpBody = data
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
        return request
    }
}
