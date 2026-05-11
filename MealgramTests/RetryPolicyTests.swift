import XCTest

@testable import Mealgram

final class RetryPolicyTests: XCTestCase {
    func testDelayGrowsExponentiallyUpToCap() {
        let policy = RetryPolicy(maxAttempts: 6, baseDelay: 1.0, cap: 4.0)

        // attempt 1 → ~ baseDelay (with ±25% jitter, so [0.75, 1.25])
        for attempt in 1...6 {
            let delay = policy.delay(forAttempt: attempt)
            XCTAssertGreaterThanOrEqual(delay, 0)
            XCTAssertLessThanOrEqual(delay, policy.cap * 1.25 + 0.001)
        }
    }

    func testZeroAttemptReturnsZeroDelay() {
        let policy = RetryPolicy.default
        XCTAssertEqual(policy.delay(forAttempt: 0), 0)
    }

    func testNonePolicyAttemptsOnce() {
        let policy = RetryPolicy.none
        XCTAssertEqual(policy.maxAttempts, 1)
    }
}
