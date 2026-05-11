import XCTest

@testable import Mealgram

final class APIErrorTests: XCTestCase {
    func testIsRetryableMatchesContract() {
        XCTAssertTrue(APIError.transport(.timedOut).isRetryable)
        XCTAssertTrue(APIError.transport(.networkConnectionLost).isRetryable)
        XCTAssertTrue(APIError.transport(.notConnectedToInternet).isRetryable)
        XCTAssertTrue(APIError.http(status: 500, body: nil).isRetryable)
        XCTAssertTrue(APIError.http(status: 503, body: nil).isRetryable)
        XCTAssertFalse(APIError.http(status: 400, body: nil).isRetryable)
        XCTAssertFalse(APIError.http(status: 401, body: nil).isRetryable)
        XCTAssertFalse(APIError.notConfigured.isRetryable)
        XCTAssertFalse(APIError.decoding(reason: "x").isRetryable)
        XCTAssertFalse(APIError.unauthorized.isRetryable)
    }

    func testEveryCaseHasUserMessage() {
        let cases: [APIError] = [
            .notConfigured,
            .transport(.timedOut),
            .http(status: 500, body: nil),
            .http(status: 503, body: nil),
            .unauthorized,
            .decoding(reason: "type mismatch"),
            .unknown(reason: "boom"),
        ]
        for kase in cases {
            XCTAssertFalse(kase.userMessage.isEmpty)
        }
    }
}
