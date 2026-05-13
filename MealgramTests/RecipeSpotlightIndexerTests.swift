import CoreSpotlight
import XCTest

@testable import Mealgram

@MainActor
final class RecipeSpotlightIndexerTests: XCTestCase {

    func testMakeItemUsesTitleAndSummary() {
        let recipe = Recipe(
            title: "Pierogi ruskie",
            summary: "Klasyczne z twarogiem i ziemniakami",
            servings: 4
        )
        let item = RecipeSpotlightIndexer.makeItem(from: recipe)
        XCTAssertEqual(item.uniqueIdentifier, recipe.id.uuidString)
        XCTAssertEqual(item.domainIdentifier, RecipeSpotlightIndexer.domainIdentifier)
        XCTAssertEqual(item.attributeSet.title, "Pierogi ruskie")
        XCTAssertEqual(
            item.attributeSet.contentDescription,
            "Klasyczne z twarogiem i ziemniakami"
        )
    }

    func testMakeItemFallsBackToIngredientNamesWhenSummaryMissing() {
        let recipe = Recipe(title: "Sałatka", servings: 2)
        recipe.ingredients = [
            RecipeIngredient(name: "Awokado"),
            RecipeIngredient(name: "Pomidor"),
        ]
        let item = RecipeSpotlightIndexer.makeItem(from: recipe)
        XCTAssertEqual(item.attributeSet.contentDescription, "Awokado, Pomidor")
    }

    func testMakeItemKeywordsIncludeIngredients() {
        let recipe = Recipe(title: "Zupa", servings: 4)
        recipe.ingredients = [
            RecipeIngredient(name: "Marchew"),
            RecipeIngredient(name: "Pietruszka"),
        ]
        let item = RecipeSpotlightIndexer.makeItem(from: recipe)
        let keywords = Set(item.attributeSet.keywords ?? [])
        XCTAssertTrue(keywords.contains("Marchew"))
        XCTAssertTrue(keywords.contains("Pietruszka"))
        XCTAssertTrue(keywords.contains("Mealgram"))
        XCTAssertTrue(keywords.contains("przepis"))
    }
}

/// Fake stand-in used by RecipeRepositoryTests to assert that mutations
/// trigger the right Spotlight calls without hitting CoreSpotlight.
@MainActor
final class FakeRecipeSpotlightIndexer: RecipeSpotlightIndexing {
    private(set) var indexedIDs: [UUID] = []
    private(set) var removedIDs: [UUID] = []
    private(set) var batchCounts: [Int] = []

    func index(_ recipe: Recipe) {
        indexedIDs.append(recipe.id)
    }

    func remove(recipeID: UUID) {
        removedIDs.append(recipeID)
    }

    func indexAll(_ recipes: [Recipe]) {
        batchCounts.append(recipes.count)
    }

    func removeAll() {
        batchCounts.append(0)
    }
}

@MainActor
final class RecipeRepoSpotlightTests: XCTestCase {
    private var controller: PersistenceController!
    private var indexer: FakeRecipeSpotlightIndexer!
    private var repository: RecipeRepository!

    override func setUp() async throws {
        controller = try PersistenceController.makeInMemory()
        indexer = FakeRecipeSpotlightIndexer()
        repository = RecipeRepository(
            container: controller.container,
            spotlightIndexer: indexer
        )
    }

    override func tearDown() async throws {
        controller = nil
        indexer = nil
        repository = nil
    }

    func testCreateTriggersIndex() throws {
        let recipe = Recipe(title: "Naleśniki", servings: 2)
        _ = try repository.create(recipe)
        XCTAssertEqual(indexer.indexedIDs, [recipe.id])
    }

    func testDeleteTriggersRemove() throws {
        let recipe = Recipe(title: "Naleśniki", servings: 2)
        _ = try repository.create(recipe)
        try repository.delete(recipe)
        XCTAssertEqual(indexer.removedIDs, [recipe.id])
    }

    func testDuplicateIndexesCopy() throws {
        let recipe = Recipe(title: "Naleśniki", servings: 2)
        _ = try repository.create(recipe)
        let copy = try repository.duplicate(recipe)
        XCTAssertTrue(indexer.indexedIDs.contains(copy.id))
    }

    func testReindexSpotlightSendsBatch() throws {
        _ = try repository.create(Recipe(title: "A", servings: 1))
        _ = try repository.create(Recipe(title: "B", servings: 1))
        try repository.reindexSpotlight()
        XCTAssertEqual(indexer.batchCounts.last, 2)
    }
}
