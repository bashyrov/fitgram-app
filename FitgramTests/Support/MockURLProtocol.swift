import Foundation

/// In-process URL protocol that lets tests stub responses without going to
/// the network. Register with a `URLSessionConfiguration.ephemeral` session
/// and set `MockURLProtocol.handler` to return whatever the test needs.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data?)

    nonisolated(unsafe) static var handler: Handler?
    nonisolated(unsafe) static var capturedRequests: [URLRequest] = []
    nonisolated(unsafe) static var requestSequence: [Result<(HTTPURLResponse, Data?), any Error>] = []
    nonisolated(unsafe) private static var sequenceIndex: Int = 0
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        handler = nil
        capturedRequests = []
        requestSequence = []
        sequenceIndex = 0
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        MockURLProtocol.lock.lock()
        MockURLProtocol.capturedRequests.append(request)
        let result: Result<(HTTPURLResponse, Data?), Error>
        if !MockURLProtocol.requestSequence.isEmpty {
            let index = min(MockURLProtocol.sequenceIndex, MockURLProtocol.requestSequence.count - 1)
            result = MockURLProtocol.requestSequence[index]
            MockURLProtocol.sequenceIndex += 1
        } else if let handler = MockURLProtocol.handler {
            do {
                result = .success(try handler(request))
            } catch {
                result = .failure(error)
            }
        } else {
            result = .failure(URLError(.badServerResponse))
        }
        MockURLProtocol.lock.unlock()

        switch result {
        case .success(let (response, data)):
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data, !data.isEmpty {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        case .failure(let error):
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

extension MockURLProtocol {
    static func makeResponse(url: URL, status: Int, body: Data? = nil) -> (HTTPURLResponse, Data?) {
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )
        else {
            fatalError("HTTPURLResponse init returned nil — unreachable for valid input")
        }
        return (response, body)
    }
}
