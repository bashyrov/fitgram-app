import XCTest

@testable import Mealgram

@MainActor
final class VoiceMealParserTests: XCTestCase {
    private func food(
        name: String,
        kcal: Double = 100,
        protein: Double = 0,
        portion: Double? = nil
    ) -> Food {
        Food(
            name: name,
            caloriesKcalPer100g: kcal,
            proteinGramsPer100g: protein,
            defaultPortionGrams: portion
        )
    }

    // MARK: - Extraction primitives

    func testExtractGramsHandlesMultipleSuffixes() {
        XCTAssertEqual(VoiceMealParser.extractGrams(from: "kanapka 250 g"), 250)
        XCTAssertEqual(VoiceMealParser.extractGrams(from: "schabowy 180 gram"), 180)
        XCTAssertEqual(VoiceMealParser.extractGrams(from: "owsianka 300 gramów"), 300)
        XCTAssertEqual(VoiceMealParser.extractGrams(from: "sałatka 150gr"), 150)
    }

    func testExtractGramsHandlesDecimals() {
        XCTAssertEqual(VoiceMealParser.extractGrams(from: "olej 12,5 g"), 12.5)
    }

    func testExtractCalories() {
        XCTAssertEqual(VoiceMealParser.extractCalories(from: "obiad 700 kalorii"), 700)
        XCTAssertEqual(VoiceMealParser.extractCalories(from: "obiad 700 kcal"), 700)
        XCTAssertEqual(VoiceMealParser.extractCalories(from: "obiad 700 kal"), 700)
    }

    func testExtractMissingPatternReturnsNil() {
        XCTAssertNil(VoiceMealParser.extractGrams(from: "po prostu kanapka"))
        XCTAssertNil(VoiceMealParser.extractCalories(from: "obiad bez liczb"))
    }

    // MARK: - Full parse

    func testTranscriptWithoutNumbersFallsBackToPlaceholder() {
        let parser = VoiceMealParser()
        let item = parser.parse("schabowy")
        XCTAssertEqual(item.name.lowercased(), "schabowy")
        XCTAssertEqual(item.quantityGrams, 100)
        XCTAssertEqual(item.caloriesKcal, 0)
    }

    func testTranscriptWithGramsAndKcal() {
        let parser = VoiceMealParser()
        let item = parser.parse("kanapka 250 g 400 kcal")
        XCTAssertEqual(item.quantityGrams, 250)
        XCTAssertEqual(item.caloriesKcal, 400)
        XCTAssertEqual(item.name.lowercased(), "kanapka")
    }

    func testCatalogMatchHydratesMacros() {
        let kurczak = food(name: "Kurczak grillowany", kcal: 165, protein: 31, portion: 150)
        let parser = VoiceMealParser(catalog: [kurczak])
        let item = parser.parse("kurczak 200 gram")
        XCTAssertEqual(item.catalogFoodID, kurczak.id)
        XCTAssertEqual(item.name, "Kurczak grillowany")
        XCTAssertEqual(item.quantityGrams, 200)
        XCTAssertEqual(item.caloriesKcal, 330, accuracy: 0.01)
        XCTAssertEqual(item.proteinGrams, 62, accuracy: 0.01)
    }

    func testCatalogMatchUsesDefaultPortionWhenGramsMissing() {
        let banan = food(name: "Banan", kcal: 89, portion: 120)
        let parser = VoiceMealParser(catalog: [banan])
        let item = parser.parse("banan")
        XCTAssertEqual(item.quantityGrams, 120)
        XCTAssertEqual(item.caloriesKcal, 89 * 1.2, accuracy: 0.01)
    }

    func testExplicitKcalOverridesCatalog() {
        let owsianka = food(name: "Owsianka", kcal: 200, portion: 100)
        let parser = VoiceMealParser(catalog: [owsianka])
        let item = parser.parse("owsianka 300 kalorii")
        XCTAssertEqual(item.caloriesKcal, 300)
        XCTAssertEqual(item.catalogFoodID, owsianka.id)
    }

    func testEmptyTranscriptProducesPlaceholder() {
        let parser = VoiceMealParser()
        let item = parser.parse("   ")
        XCTAssertEqual(item.quantityGrams, 100)
        XCTAssertEqual(item.caloriesKcal, 0)
    }

    // MARK: - Multi-item

    func testSplitOnPolishConnectives() {
        let pieces = VoiceMealParser.split("jajka i tost oraz kawa, sok")
        XCTAssertEqual(pieces, ["jajka", "tost", "kawa", "sok"])
    }

    func testParseMultipleReturnsOneItemPerSegment() {
        let parser = VoiceMealParser()
        let items = parser.parseMultiple("schabowy 200 gram i ziemniaki 250 g")
        XCTAssertEqual(items.count, 2)
        XCTAssertTrue(items.contains { $0.name.lowercased().contains("schabowy") })
        XCTAssertTrue(items.contains { $0.name.lowercased().contains("ziemniaki") })
    }

    func testParseMultipleFallsBackToSingleItemWhenUnsplit() {
        let parser = VoiceMealParser()
        let items = parser.parseMultiple("kanapka 250 g 400 kcal")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.caloriesKcal, 400)
    }

    // MARK: - Decimal + comma edge cases

    func testCommaDecimalSeparatorParsed() {
        let parser = VoiceMealParser()
        let item = parser.parse("masło 12,5 g")
        XCTAssertEqual(item.quantityGrams, 12.5, accuracy: 0.01)
    }

    func testHandlesShortFormGramUnit() {
        let parser = VoiceMealParser()
        let item = parser.parse("ryż 80g")
        XCTAssertEqual(item.quantityGrams, 80)
    }

    func testHandlesGramówSuffix() {
        let parser = VoiceMealParser()
        let item = parser.parse("schab 200 gramów")
        XCTAssertEqual(item.quantityGrams, 200)
    }

    func testKalorieSuffixAccepted() {
        let parser = VoiceMealParser()
        let item = parser.parse("tort 350 kalorie")
        XCTAssertEqual(item.caloriesKcal, 350)
    }

    // MARK: - Connective splitting edge cases

    func testSplitIgnoresIInsideWord() {
        // Polish word "iść" starts with "i" — must not split it.
        let pieces = VoiceMealParser.split("iść do sklepu")
        XCTAssertEqual(pieces.count, 1)
    }

    func testSplitHandlesPlusOnly() {
        let pieces = VoiceMealParser.split("kawa plus mleko")
        XCTAssertEqual(pieces, ["kawa", "mleko"])
    }

    func testParseMultipleSkipsEmptyFragments() {
        let parser = VoiceMealParser()
        // Double comma → empty middle fragment must drop.
        let items = parser.parseMultiple("jajka,, tost")
        XCTAssertEqual(items.count, 2)
    }
}
