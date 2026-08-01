import XCTest

@testable import Mealgram

final class OlaChefTests: XCTestCase {
    func testCatalogHasLargeInternationalCoverage() {
        let catalog = OlaChefCatalog.shared
        XCTAssertGreaterThanOrEqual(catalog.dishes.count, 1_000)
        let cuisines = Set(catalog.dishes.map(\.cuisine))
        XCTAssertGreaterThanOrEqual(cuisines.count, 18)
        XCTAssertTrue(cuisines.contains("Polish"))
        XCTAssertTrue(cuisines.contains("Italian"))
        XCTAssertTrue(cuisines.contains("Japanese"))
        XCTAssertTrue(cuisines.contains("Indian"))
        XCTAssertTrue(cuisines.contains("Mexican"))
    }

    func testSuggestionsScaleToTargetCalories() {
        let catalog = OlaChefCatalog.shared
        let request = OlaChefRequest(
            targetCalories: 600,
            mealType: .lunch,
            preferences: [.highProtein]
        )
        let suggestions = catalog.suggestions(for: request, limit: 10)
        XCTAssertFalse(suggestions.isEmpty)
        for suggestion in suggestions {
            XCTAssertLessThanOrEqual(abs(suggestion.caloriesKcal - 600), 1.0)
            XCTAssertGreaterThan(suggestion.ingredients.count, 1)
            XCTAssertGreaterThan(suggestion.servingGrams, 100)
        }
    }

    func testCatalogDoesNotExposeGenericIngredientsAndHasSupportedLanguages() {
        let languages = ["en", "pl", "uk", "ru", "es"]
        let forbiddenIngredientNames = Set(["main protein", "grain base", "vegetables", "sauce", "sauge"])

        for dish in OlaChefCatalog.shared.dishes {
            for language in languages {
                XCTAssertFalse(dish.name(languageCode: language).isEmpty, dish.id)
            }

            for ingredient in dish.ingredients {
                XCTAssertFalse(forbiddenIngredientNames.contains(ingredient.name(languageCode: "en")), ingredient.id)
                for language in languages {
                    XCTAssertFalse(ingredient.name(languageCode: language).isEmpty, ingredient.id)
                }
            }
        }
    }

    func testSuggestionsDoNotRepeatGeneratedDishUnderDifferentCuisines() {
        let suggestions = OlaChefCatalog.shared.suggestions(
            for: OlaChefRequest(targetCalories: 600, mealType: .lunch, preferences: [.highProtein]),
            limit: 72
        )
        var seenTemplates = Set<String>()
        for suggestion in suggestions {
            guard let range = suggestion.dish.id.range(of: ".template.") else { continue }
            let suffix = suggestion.dish.id[range.upperBound...]
            let templateIndex = suffix.split(separator: ".").first.map(String.init) ?? String(suffix)
            XCTAssertTrue(
                seenTemplates.insert(templateIndex).inserted,
                "Duplicate generated template \(templateIndex): \(suggestion.dish.id)"
            )
        }
    }
}
