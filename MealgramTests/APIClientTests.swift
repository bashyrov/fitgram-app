import XCTest

@testable import Mealgram

@MainActor
final class APIClientTests: XCTestCase {
    private static let baseURL: URL = {
        guard let url = URL(string: "https://worker.mealgram.test") else {
            fatalError("static test base URL is invalid")
        }
        return url
    }()
    private var baseURL: URL { Self.baseURL }
    private var session: URLSession!

    override func setUp() async throws {
        MockURLProtocol.reset()
        session = MockURLProtocol.makeSession()
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
    }

    // MARK: - Happy path

    func testSuccessfulGETDecodesResponse() async throws {
        let payload = Data(#"{"message":"hi"}"#.utf8)
        let fallbackURL = Self.baseURL
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/hello")
            return MockURLProtocol.makeResponse(url: request.url ?? fallbackURL, status: 200, body: payload)
        }

        let client = URLSessionAPIClient(
            session: session, baseURL: baseURL, interceptors: [], retryPolicy: .none
        )
        struct Reply: Decodable, Sendable { let message: String }
        let result = try await client.send(
            Endpoint(path: "/api/v1/hello", requiresAuth: false), expecting: Reply.self
        )
        XCTAssertEqual(result.message, "hi")
    }

    // MARK: - JWT injection

    func testAuthInterceptorAddsBearerHeader() async throws {
        let keychain = Keychain(service: "app.mealgram.tests.apiclient.auth")
        defer { try? keychain.removeAll() }
        let tokenStore = TokenStore(keychain: keychain)
        try tokenStore.save(
            session: AuthCredentials.fixture(userID: "u-1", provider: .apple)
        )

        let fallbackURL = Self.baseURL
        MockURLProtocol.handler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization")
            XCTAssertEqual(auth, "Bearer access-token-u-1")
            return MockURLProtocol.makeResponse(
                url: request.url ?? fallbackURL, status: 200, body: Data("{}".utf8)
            )
        }

        let client = URLSessionAPIClient(
            session: session,
            baseURL: baseURL,
            interceptors: [AuthInterceptor(tokenStore: tokenStore)],
            retryPolicy: .none
        )
        try await client.send(Endpoint(path: "/v1/me"))
    }

    func testAuthInterceptorThrowsWhenNoToken() async throws {
        let keychain = Keychain(service: "app.mealgram.tests.apiclient.noauth")
        defer { try? keychain.removeAll() }
        try? keychain.removeAll()
        let tokenStore = TokenStore(keychain: keychain)
        let client = URLSessionAPIClient(
            session: session,
            baseURL: baseURL,
            interceptors: [AuthInterceptor(tokenStore: tokenStore)],
            retryPolicy: .none
        )
        do {
            try await client.send(Endpoint(path: "/v1/me"))
            XCTFail("Expected APIError.unauthorized")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: - Retry

    func testRetriesOn503ThenSucceeds() async throws {
        let url = baseURL.appendingPathComponent("/v1/retry")
        let success = MockURLProtocol.makeResponse(url: url, status: 200, body: Data("{}".utf8))
        let failure = MockURLProtocol.makeResponse(url: url, status: 503)
        MockURLProtocol.requestSequence = [.success(failure), .success(success)]

        let client = URLSessionAPIClient(
            session: session,
            baseURL: baseURL,
            interceptors: [],
            retryPolicy: RetryPolicy(maxAttempts: 3, baseDelay: 0.001, cap: 0.01)
        )
        try await client.send(Endpoint(path: "/v1/retry", requiresAuth: false))
        XCTAssertEqual(MockURLProtocol.capturedRequests.count, 2)
    }

    func testNoRetryOnClientError() async throws {
        let url = baseURL.appendingPathComponent("/v1/bad")
        MockURLProtocol.requestSequence = [
            .success(MockURLProtocol.makeResponse(url: url, status: 400, body: nil)),
            .success(MockURLProtocol.makeResponse(url: url, status: 200, body: Data("{}".utf8))),
        ]
        let client = URLSessionAPIClient(
            session: session,
            baseURL: baseURL,
            interceptors: [],
            retryPolicy: RetryPolicy(maxAttempts: 3, baseDelay: 0.001, cap: 0.01)
        )
        do {
            try await client.send(Endpoint(path: "/v1/bad", requiresAuth: false))
            XCTFail("Expected APIError.http(400, _)")
        } catch let APIError.http(status, _) {
            XCTAssertEqual(status, 400)
            XCTAssertEqual(MockURLProtocol.capturedRequests.count, 1)
        }
    }

    // MARK: - Transport errors

    func testTransportErrorMapsToAPIError() async throws {
        MockURLProtocol.handler = { _ in
            throw URLError(.notConnectedToInternet)
        }
        let client = URLSessionAPIClient(
            session: session, baseURL: baseURL, interceptors: [], retryPolicy: .none
        )
        do {
            try await client.send(Endpoint(path: "/v1/x", requiresAuth: false))
            XCTFail("Expected APIError.transport")
        } catch let APIError.transport(code) {
            XCTAssertEqual(code, .notConnectedToInternet)
        }
    }
}
