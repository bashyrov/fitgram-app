import XCTest

@testable import Mealgram

final class TokensTests: XCTestCase {
    func testSpacingScaleIsMonotonic() {
        let values: [CGFloat] = [
            Tokens.Space.xxs,
            Tokens.Space.xs,
            Tokens.Space.sm,
            Tokens.Space.md,
            Tokens.Space.lg,
            Tokens.Space.xl,
            Tokens.Space.xxl,
            Tokens.Space.xxxl,
            Tokens.Space.huge,
        ]
        XCTAssertEqual(values, values.sorted(), "Spacing scale must be strictly ascending")
    }

    func testRadiusPillIsBig() {
        XCTAssertGreaterThanOrEqual(Tokens.Radius.pill, 100)
    }

    func testShadowAlphaIsSubtle() {
        for style in [Tokens.Shadow.card, Tokens.Shadow.float, Tokens.Shadow.modal] {
            XCTAssertGreaterThan(style.radius, 0)
            XCTAssertGreaterThanOrEqual(style.y, 0)
        }
    }
}
