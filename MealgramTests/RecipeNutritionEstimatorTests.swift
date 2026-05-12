import XCTest

@testable import Mealgram

@MainActor
final class RecipeNutritionEstimatorTests: XCTestCase {
    private static func food(
        name: String,
        kcal: Double,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        portion: Double? = nil
    ) -> Food {
        Food(
            name: name,
            caloriesKcalPer100g: kcal,
            proteinGramsPer100g: protein,
            carbsGramsPer100g: carbs,
            fatGramsPer100g: fat,
            defaultPortionGrams: portion
        )
    }

    func testExactNameMatchReturnsThatFood() {
        let kurczak = Self.food(name: "Kurczak grillowany", kcal: 165, protein: 31)
        let banan = Self.food(name: "Banan", kcal: 89, protein: 1.1)
        let estimator = RecipeNutritionEstimator(catalog: [kurczak, banan])
        XCTAssertEqual(estimator.bestMatch(for: "Kurczak grillowany")?.name, "Kurczak grillowany")
        XCTAssertEqual(estimator.bestMatch(for: "Banan")?.name, "Banan")
    }

    func testFuzzyMatchOnSharedTokens() {
        let kurczak = Self.food(name: "Kurczak grillowany", kcal: 165, protein: 31)
        let estimator = RecipeNutritionEstimator(catalog: [kurczak])
        // "Kurczak z piersi" shares "Kurczak" → matches.
        XCTAssertEqual(estimator.bestMatch(for: "Kurczak z piersi")?.name, "Kurczak grillowany")
    }

    func testShortTokensIgnoredByTokenizer() {
        let banan = Self.food(name: "Banan", kcal: 89)
        let estimator = RecipeNutritionEstimator(catalog: [banan])
        // "do" / "ba" / "na" are < 4 chars; only ingredient with no shared
        // significant token returns nil.
        XCTAssertNil(estimator.bestMatch(for: "ba na do"))
    }

    func testNoCatalogReturnsNilAndReportsUnmatched() {
        let estimator = RecipeNutritionEstimator(catalog: [])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Schabowy", quantityGrams: nil)],
            servings: 2
        )
        XCTAssertEqual(estimate.matched, 0)
        XCTAssertEqual(estimate.unmatched, ["Schabowy"])
        XCTAssertEqual(estimate.perServingCalories, 0)
    }

    func testQuantityGramsOverrideDefaultPortion() {
        let banan = Self.food(name: "Banan", kcal: 100, protein: 1, portion: 100)
        let estimator = RecipeNutritionEstimator(catalog: [banan])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Banan", quantityGrams: 200)],
            servings: 1
        )
        // 200g of 100 kcal/100g → 200 kcal for the recipe / 1 serving.
        XCTAssertEqual(estimate.perServingCalories, 200, accuracy: 0.001)
        XCTAssertEqual(estimate.perServingProtein, 2, accuracy: 0.001)
    }

    func testFallsBackToCatalogDefaultPortion() {
        let banan = Self.food(name: "Banan", kcal: 89, portion: 120)
        let estimator = RecipeNutritionEstimator(catalog: [banan])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Banan", quantityGrams: nil)],
            servings: 1
        )
        // 120g of 89 kcal/100g = 106.8 kcal.
        XCTAssertEqual(estimate.perServingCalories, 106.8, accuracy: 0.01)
    }

    func testFallsBackToConservativeFallbackWhenNoPortion() {
        let mystery = Self.food(name: "Mystery", kcal: 100, portion: nil)
        let estimator = RecipeNutritionEstimator(catalog: [mystery])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Mystery", quantityGrams: nil)],
            servings: 1
        )
        // Fallback grams (80) × 100 kcal/100g = 80 kcal.
        XCTAssertEqual(estimate.perServingCalories, 80, accuracy: 0.001)
    }

    func testTotalsDividedByServings() {
        let kurczak = Self.food(name: "Kurczak", kcal: 200, protein: 30, portion: 100)
        let estimator = RecipeNutritionEstimator(catalog: [kurczak])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Kurczak", quantityGrams: 400)],  // 800 kcal total
            servings: 4
        )
        XCTAssertEqual(estimate.perServingCalories, 200, accuracy: 0.001)
    }

    func testZeroServingsReturnsZeroedEstimate() {
        let banan = Self.food(name: "Banan", kcal: 100)
        let estimator = RecipeNutritionEstimator(catalog: [banan])
        let estimate = estimator.estimate(
            ingredients: [.init(name: "Banan", quantityGrams: 100)],
            servings: 0
        )
        XCTAssertEqual(estimate.matched, 0)
        XCTAssertEqual(estimate.perServingCalories, 0)
    }
}
