import XCTest

@testable import Fitgram

final class FitgramTests: XCTestCase {
    /// Sanity check that the design-system tokens namespace compiles and exposes
    /// the brand palette + spacing scale. Replaced with real unit tests in
    /// Milestone 1.2 once SwiftData models land.
    func testTokensNamespaceIsAvailable() {
        XCTAssertEqual(Tokens.Space.lg, 16)
        XCTAssertEqual(Tokens.Radius.pill, 999)
        XCTAssertEqual(Tokens.Shadow.card.radius, 10)
    }
}
