import XCTest

@testable import Fitgram

final class MonoStepperParseTests: XCTestCase {
    func testParsesCommaAndDotDecimals() {
        XCTAssertEqual(MonoStepper.parse("72,5"), 72.5)
        XCTAssertEqual(MonoStepper.parse("72.5"), 72.5)
        XCTAssertEqual(MonoStepper.parse(" 175 "), 175)
    }

    func testTreatsAnySingleNonDigitAsSeparator() {
        XCTAssertEqual(MonoStepper.parse("72б5"), 72.5)
        XCTAssertEqual(MonoStepper.parse("1.2.3"), 1.23)
    }

    func testRejectsEmptyOrNonNumeric() {
        XCTAssertNil(MonoStepper.parse(""))
        XCTAssertNil(MonoStepper.parse("abc"))
    }
}
