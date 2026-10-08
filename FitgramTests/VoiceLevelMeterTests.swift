import XCTest

@testable import Fitgram

@MainActor
final class VoiceLevelMeterTests: XCTestCase {
    func testDecibelMapping() {
        XCTAssertEqual(VoiceLevelMeter.normalized(decibels: -80), 0)
        XCTAssertEqual(VoiceLevelMeter.normalized(decibels: -30), 0.5, accuracy: 0.001)
        XCTAssertEqual(VoiceLevelMeter.normalized(decibels: 0), 1)
    }

    func testPushKeepsNewestOnTheRight() {
        let meter = VoiceLevelMeter()
        meter.push(0.4)
        meter.push(0.9)
        XCTAssertEqual(meter.levels.count, VoiceLevelMeter.barCount)
        XCTAssertEqual(meter.levels.suffix(2), [0.4, 0.9])
        meter.reset()
        XCTAssertTrue(meter.levels.allSatisfy { $0 == 0 })
    }
}
