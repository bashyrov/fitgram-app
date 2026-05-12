import SwiftData
import XCTest

@testable import Mealgram

@MainActor
final class RecipeRepositoryTests: XCTestCase {
    private var controller: PersistenceController!
    private var repository: RecipeRepository!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        repository = RecipeRepository(container: controller.container)
    }

    override func tearDown() async throws {
        controller = nil
        repository = nil
    }

    func testCreateAndFetchAll() throws {
        let recipe = Recipe(title: "Pierogi ruskie", servings: 4)
        try repository.create(recipe)
        let all = try repository.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.title, "Pierogi ruskie")
    }

    func testDeleteRemovesRow() throws {
        let recipe = Recipe(title: "Test", servings: 1)
        try repository.create(recipe)
        try repository.delete(recipe)
        XCTAssertTrue(try repository.all().isEmpty)
    }

    func testCookProducesMealEntryWithRecipeSource() {
        let recipe = Recipe(title: "Schabowy z ziemniakami", servings: 2)
        recipe.caloriesPerServing = 800
        recipe.proteinPerServing = 40
        recipe.carbsPerServing = 60
        recipe.fatPerServing = 30
        let entry = repository.cook(recipe, servings: 1.5)
        XCTAssertEqual(entry.source, .recipe)
        XCTAssertEqual(entry.items.count, 1)
        let item = entry.items[0]
        XCTAssertEqual(item.name, "Schabowy z ziemniakami")
        XCTAssertEqual(item.caloriesKcal, 1200, accuracy: 0.001)
        XCTAssertEqual(item.proteinGrams, 60, accuracy: 0.001)
        XCTAssertEqual(recipe.cookCount, 1, "cookCount should increment")
    }

    func testCookHandlesMissingNutrition() {
        let recipe = Recipe(title: "Bez kalorii", servings: 1)
        let entry = repository.cook(recipe)
        XCTAssertEqual(entry.items.first?.caloriesKcal, 0)
        XCTAssertEqual(recipe.cookCount, 1)
    }

    func testSuggestedMealTypeByHour() {
        XCTAssertEqual(RecipeRepository.suggestedMealType(forHour: 8), .breakfast)
        XCTAssertEqual(RecipeRepository.suggestedMealType(forHour: 13), .lunch)
        XCTAssertEqual(RecipeRepository.suggestedMealType(forHour: 19), .dinner)
        XCTAssertEqual(RecipeRepository.suggestedMealType(forHour: 23), .snack)
    }
}
