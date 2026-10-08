import XCTest

@testable import Fitgram

final class MonoTicksTests: XCTestCase {
    func testRoundsDownToFullyEarnedTicks() {
        XCTAssertEqual(MonoTicks.filledCount(progress: 0.85, count: 30), 25)
        XCTAssertEqual(MonoTicks.filledCount(progress: 0.0333, count: 30), 0)
    }

    func testExactFractionsAreKept() {
        XCTAssertEqual(MonoTicks.filledCount(progress: 0.3, count: 30), 9)
        XCTAssertEqual(MonoTicks.filledCount(progress: 1, count: 30), 30)
    }

    func testClampsOutOfRange() {
        XCTAssertEqual(MonoTicks.filledCount(progress: 1.4, count: 30), 30)
        XCTAssertEqual(MonoTicks.filledCount(progress: -0.2, count: 30), 0)
    }
}
