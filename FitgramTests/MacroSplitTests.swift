import XCTest

@testable import Fitgram

final class MacroSplitTests: XCTestCase {

    func testBalancedSplitAt2000Kcal() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "balanced" })
        let grams = split.grams(forCalories: 2000)
        // DietMacroPreset.balanced is 25 / 45 / 30.
        // 25% of 2000 = 500 kcal protein → 125g
        XCTAssertEqual(grams.protein, 125)
        // 45% of 2000 = 900 kcal carbs → 225g
        XCTAssertEqual(grams.carbs, 225)
        // 30% of 2000 = 600 kcal fat → 67g (600/9 = 66.67 → 67)
        XCTAssertEqual(grams.fat, 67)
    }

    func testKetoSplitFavorsFat() throws {
        let split = try XCTUnwrap(MacroSplit.presets.first { $0.id == "keto" })
        let grams = split.grams(forCalories: 2000)
        // DietMacroPreset.keto is 20 / 5 / 75.
        XCTAssertEqual(grams.protein, 100)
        XCTAssertEqual(grams.carbs, 25)
        // 75% of 2000 = 1500 kcal fat → 167g (1500/9 = 166.67 → 167)
        XCTAssertEqual(grams.fat, 167)
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
