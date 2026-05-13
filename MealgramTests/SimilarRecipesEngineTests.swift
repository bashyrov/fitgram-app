import XCTest

@testable import Mealgram

final class SimilarRecipesEngineTests: XCTestCase {
    private func recipe(_ title: String, ingredients: [String]) -> Recipe {
        let recipe = Recipe(title: title)
        recipe.ingredients = ingredients.map { RecipeIngredient(name: $0) }
        return recipe
    }

    func testReturnsRecipesSortedBySharedTokens() {
        let source = recipe("Schabowy z ziemniakami", ingredients: ["kotlet schabowy", "ziemniaki", "kapusta kiszona"])
        let zalewajka = recipe("Zalewajka", ingredients: ["ziemniaki", "kiełbasa", "śmietana"])
        let pierogi = recipe("Pierogi z kapustą", ingredients: ["mąka", "kapusta kiszona", "grzyby"])
        let salatka = recipe("Sałatka grecka", ingredients: ["pomidor", "feta", "ogórek"])
        let result = SimilarRecipesEngine.similar(to: source, in: [zalewajka, pierogi, salatka])
        // zalewajka shares 1 (ziemniaki), pierogi shares 2 (kapusta, kiszona),
        // salatka shares 0. Order: pierogi > zalewajka.
        XCTAssertEqual(result.map(\.title), ["Pierogi z kapustą", "Zalewajka"])
    }

    func testExcludesSelfAndZeroOverlap() {
        let source = recipe("Schabowy", ingredients: ["kotlet schabowy", "ziemniaki"])
        let salatka = recipe("Sałatka grecka", ingredients: ["pomidor", "feta"])
        let result = SimilarRecipesEngine.similar(to: source, in: [source, salatka])
        XCTAssertTrue(result.isEmpty, "Self + zero-overlap candidate should both filter out")
    }

    func testLimitClampsOutput() {
        let source = recipe("Bazowy", ingredients: ["kapusta", "marchew"])
        let peers = (0..<10).map { recipe("Sąsiad \($0)", ingredients: ["kapusta", "marchew"]) }
        let result = SimilarRecipesEngine.similar(to: source, in: peers, limit: 3)
        XCTAssertEqual(result.count, 3)
    }
}
