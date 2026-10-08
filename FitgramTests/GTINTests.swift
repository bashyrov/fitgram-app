import XCTest

@testable import Fitgram

final class GTINTests: XCTestCase {
    func testAcceptsValidEAN13() {
        XCTAssertEqual(GTIN.normalize("5449000000996"), "5449000000996")
    }

    func testRejectsBadCheckDigit() {
        XCTAssertNil(GTIN.normalize("5449000000997"))
    }

    func testRejectsNonProductCodes() {
        XCTAssertNil(GTIN.normalize("https://example.com"))
        XCTAssertNil(GTIN.normalize("12345"))
        XCTAssertNil(GTIN.normalize("ABC1234567890"))
    }

    func testAcceptsValidEAN8() {
        XCTAssertEqual(GTIN.normalize("96385074"), "96385074")
    }

    func testExpandsUPCE() {
        // UPC-E 04252614 ↔ UPC-A 042100005264.
        XCTAssertEqual(GTIN.expandUPCE("04252614"), "042100005264")
        XCTAssertTrue(GTIN.isValid("042100005264"))
        XCTAssertEqual(GTIN.lookupCandidates(for: "04252614"), ["04252614", "042100005264", "0042100005264"])
    }

    func testCandidatesBridgeUPCAAndEAN13() {
        XCTAssertEqual(GTIN.lookupCandidates(for: "0042100005264"), ["0042100005264", "042100005264"])
        XCTAssertEqual(GTIN.lookupCandidates(for: "042100005264"), ["042100005264", "0042100005264"])
        XCTAssertEqual(GTIN.lookupCandidates(for: "5449000000996"), ["5449000000996"])
    }

    func testNutrimentsFallBackToKilojoules() throws {
        let json = Data(#"{"energy-kj_100g": 1674, "proteins_100g": "5,5"}"#.utf8)
        let nutriments = try JSONDecoder().decode(OFFNutriments.self, from: json)
        XCTAssertEqual(nutriments.kcal100g, 400)
        XCTAssertEqual(nutriments.protein100g, 5.5)
    }

    func testNutrimentsPreferKcal() throws {
        let json = Data(#"{"energy-kcal_100g": 42, "energy_100g": 180}"#.utf8)
        let nutriments = try JSONDecoder().decode(OFFNutriments.self, from: json)
        XCTAssertEqual(nutriments.kcal100g, 42)
    }
}
