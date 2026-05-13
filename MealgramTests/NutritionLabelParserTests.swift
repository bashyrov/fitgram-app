import XCTest

@testable import Mealgram

final class NutritionLabelParserTests: XCTestCase {

    func testCanonicalPolishLabel() throws {
        let text = """
            Wartości odżywcze na 100 g:
            Wartość energetyczna: 1045 kJ / 250 kcal
            Tłuszcz: 12 g
            w tym kwasy nasycone: 4 g
            Węglowodany: 22 g
            w tym cukry: 3 g
            Białko: 14 g
            Sól: 1.2 g
            """
        let result = try XCTUnwrap(NutritionLabelParser.parse(text))
        XCTAssertEqual(result.kcalPer100g, 250)
        XCTAssertEqual(result.proteinGramsPer100g, 14)
        XCTAssertEqual(result.carbsGramsPer100g, 22)
        XCTAssertEqual(result.fatGramsPer100g, 12)
    }

    func testKcalOnlyLabel() throws {
        let text = "Energia 320 kcal"
        let result = try XCTUnwrap(NutritionLabelParser.parse(text))
        XCTAssertEqual(result.kcalPer100g, 320)
        // Defaults for missing macros
        XCTAssertEqual(result.proteinGramsPer100g, 0)
        XCTAssertEqual(result.carbsGramsPer100g, 0)
        XCTAssertEqual(result.fatGramsPer100g, 0)
    }

    func testHandlesCommaDecimalSeparator() throws {
        let text = "wartość energetyczna 247,5 kcal / 100 g, białko 5,3 g"
        let result = try XCTUnwrap(NutritionLabelParser.parse(text))
        XCTAssertEqual(result.kcalPer100g, 247.5)
        XCTAssertEqual(result.proteinGramsPer100g, 5.3)
    }

    func testReturnsNilWhenKcalMissing() {
        XCTAssertNil(NutritionLabelParser.parse("Skład: mąka, woda, sól"))
    }

    func testFallsBackToBareKcalNumber() throws {
        let result = try XCTUnwrap(NutritionLabelParser.parse("180 kcal"))
        XCTAssertEqual(result.kcalPer100g, 180)
    }
}
