import UIKit
import XCTest

@testable import Mealgram

@MainActor
final class StreakShareCardTests: XCTestCase {
    func testRenderProducesNonNilImage() {
        let image = StreakShareCard.render(
            streakLength: 7,
            longestLength: 12,
            displayName: "Anna"
        )
        XCTAssertNotNil(image)
    }

    func testRenderProducesPortraitSizedImage() throws {
        let image = try XCTUnwrap(
            StreakShareCard.render(streakLength: 14, longestLength: 14, displayName: nil)
        )
        XCTAssertEqual(image.size.width, 1080, accuracy: 1)
        XCTAssertEqual(image.size.height, 1920, accuracy: 1)
    }

    func testRenderToleratesZeroLongestStreak() {
        // longest = 0 + current = 1 used to crash older renderers that
        // expected longest to be set. Smoke-test that the SwiftUI path
        // still produces a usable image.
        let image = StreakShareCard.render(streakLength: 1, longestLength: 0, displayName: nil)
        XCTAssertNotNil(image)
    }

    func testRenderToleratesEmptyDisplayName() {
        let image = StreakShareCard.render(streakLength: 3, longestLength: 5, displayName: "")
        XCTAssertNotNil(image)
    }
}
