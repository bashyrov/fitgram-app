import XCTest

@testable import Mealgram

@MainActor
final class AuthErrorTests: XCTestCase {
    func testEveryCaseHasNonEmptyUserMessage() {
        let cases: [AuthError] = [
            .providerNotConfigured(.apple),
            .providerNotConfigured(.google),
            .providerNotConfigured(.email),
            .canceled,
            .invalidCredential,
            .network(underlying: "timeout"),
            .unknown(underlying: "boom"),
        ]
        for kase in cases {
            XCTAssertFalse(kase.userMessage.isEmpty, "Missing user-facing message for \(kase)")
        }
    }

    func testProviderNotConfiguredIncludesProviderName() {
        XCTAssertTrue(AuthError.providerNotConfigured(.google).userMessage.contains("Google"))
        XCTAssertTrue(AuthError.providerNotConfigured(.apple).userMessage.contains("Apple"))
    }

    func testAuthProviderKindCoversEveryRaw() {
        for kind in AuthProviderKind.allCases {
            XCTAssertEqual(AuthProviderKind(rawValue: kind.rawValue), kind)
            XCTAssertFalse(kind.displayName.isEmpty)
        }
    }
}
