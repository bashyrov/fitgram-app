import XCTest

@testable import Mealgram

@MainActor
final class RecipeListStateTests: XCTestCase {
    private func makeRecipe(
        title: String,
        cookCount: Int = 0,
        updatedAt: Date = Date()
    ) -> Recipe {
        let recipe = Recipe(title: title)
        recipe.cookCount = cookCount
        recipe.updatedAt = updatedAt
        return recipe
    }

    func testRecentSortReturnsNewestFirst() {
        let older = makeRecipe(title: "Old", updatedAt: Date(timeIntervalSince1970: 1_000_000))
        let newer = makeRecipe(title: "New", updatedAt: Date(timeIntervalSince1970: 2_000_000))
        let sorted = RecipeListState.sort([older, newer], by: .recent)
        XCTAssertEqual(sorted.map(\.title), ["New", "Old"])
    }

    func testNameAscSortIsCaseInsensitiveAlphabetical() {
        let recipes = [
            makeRecipe(title: "Żurek"),
            makeRecipe(title: "barszcz"),
            makeRecipe(title: "Bigos"),
        ]
        let sorted = RecipeListState.sort(recipes, by: .nameAsc)
        XCTAssertEqual(sorted.map(\.title), ["barszcz", "Bigos", "Żurek"])
    }

    func testCookedCountSortDescByCountThenNameAsc() {
        let anna = makeRecipe(title: "Anna", cookCount: 5)
        let bartek = makeRecipe(title: "Bartek", cookCount: 5)
        let cyryl = makeRecipe(title: "Cyryl", cookCount: 10)
        let sorted = RecipeListState.sort([anna, bartek, cyryl], by: .cookedCount)
        XCTAssertEqual(sorted.map(\.title), ["Cyryl", "Anna", "Bartek"])
    }
}
