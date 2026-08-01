import XCTest

@testable import Mealgram

final class RecipeModificationEngineTests: XCTestCase {
    override func setUp() {
        super.setUp()
        UserDefaults.standard.set("pl", forKey: "app.language")
        Bundle.setLanguage("pl")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "app.language")
        super.tearDown()
    }

    private func recipe(ingredients: [String]) -> Recipe {
        let recipe = Recipe(title: "Test")
        recipe.ingredients = ingredients.map { RecipeIngredient(name: $0) }
        return recipe
    }

    func testLighterSwapsHighFatIngredients() {
        let result = RecipeModificationEngine.suggestions(
            for: recipe(ingredients: ["śmietana 30%", "masło", "marchew"]),
            intent: .lighter
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains { $0.ingredient == "śmietan" })
        XCTAssertTrue(result.contains { $0.ingredient == "masło" })
    }

    func testGlutenFreeFiresOnFlourAndPasta() {
        let result = RecipeModificationEngine.suggestions(
            for: recipe(ingredients: ["mąka pszenna", "makaron włoski"]),
            intent: .glutenFree
        )
        XCTAssertEqual(result.count, 2)
    }

    func testReturnsEmptyForNonMatchingRecipe() {
        let result = RecipeModificationEngine.suggestions(
            for: recipe(ingredients: ["kurczak", "pomidor"]),
            intent: .lighter
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testIntentLabelsLocalised() {
        XCTAssertEqual(RecipeModificationEngine.Intent.lighter.label, "Lżejsza wersja")
        XCTAssertEqual(RecipeModificationEngine.Intent.moreProtein.label, "Więcej białka")
    }
}
