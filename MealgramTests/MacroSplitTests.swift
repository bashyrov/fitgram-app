import XCTest

@testable import Mealgram

final class MacroSplitTests: XCTestCase {

    func testBalancedSplitAt2000Kcal() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "balanced" })
        let grams = split.grams(forCalories: 2000)
        // 25% of 2000 = 500 kcal protein → 125g
        XCTAssertEqual(grams.protein, 125)
        // 50% of 2000 = 1000 kcal carbs → 250g
        XCTAssertEqual(grams.carbs, 250)
        // 25% of 2000 = 500 kcal fat → 56g (500/9 = 55.55 → 56)
        XCTAssertEqual(grams.fat, 56)
    }

    func testKetoSplitFavorsFat() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "keto" })
        let grams = split.grams(forCalories: 2000)
        XCTAssertEqual(grams.protein, 125)
        XCTAssertEqual(grams.carbs, 25)
        // 70% of 2000 = 1400 kcal fat → 156g
        XCTAssertEqual(grams.fat, 156)
    }

    func testZeroCaloriesProducesZeroGrams() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "balanced" })
        let grams = split.grams(forCalories: 0)
        XCTAssertEqual(grams.protein, 0)
        XCTAssertEqual(grams.carbs, 0)
        XCTAssertEqual(grams.fat, 0)
    }

    func testNegativeCaloriesClampedToZero() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "balanced" })
        let grams = split.grams(forCalories: -500)
        XCTAssertEqual(grams.protein, 0)
        XCTAssertEqual(grams.carbs, 0)
        XCTAssertEqual(grams.fat, 0)
    }

    func testPresetSharesSumToOne() {
        for preset in MacroSplit.presets {
            let total = preset.proteinShare + preset.carbsShare + preset.fatShare
            XCTAssertEqual(total, 1.0, accuracy: 0.001, "Preset \(preset.id) shares should sum to 1")
        }
    }
}
