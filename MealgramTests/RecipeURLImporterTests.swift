import XCTest

@testable import Mealgram

@MainActor
final class RecipeURLImporterTests: XCTestCase {
    override func setUp() async throws {
        MockURLProtocol.reset()
    }

    private static func fixtureHTML(jsonLD: String) -> String {
        """
        <html>
        <head>
        <title>Some recipe</title>
        <script type="application/ld+json">
        \(jsonLD)
        </script>
        </head>
        <body>...</body>
        </html>
        """
    }

    // MARK: - JSON-LD parsing

    func testParseSimpleRecipeJSON() throws {
        let json = """
            {
              "@context": "https://schema.org",
              "@type": "Recipe",
              "name": "Pierogi ruskie",
              "description": "Klasyczne pierogi z ziemniakami i twarogiem.",
              "recipeYield": "8",
              "recipeIngredient": [
                "500g mąki",
                "300g twarogu",
                "400g ziemniaków"
              ],
              "recipeInstructions": [
                "Ugotuj ziemniaki.",
                "Zagnieć ciasto.",
                "Lep pierogi."
              ],
              "nutrition": {
                "@type": "NutritionInformation",
                "calories": "320 kcal",
                "proteinContent": "10 g",
                "carbohydrateContent": "55 g",
                "fatContent": "6 g"
              }
            }
            """
        let html = Self.fixtureHTML(jsonLD: json)
        let importer = RecipeURLImporter()
        let draft = try importer.parse(html: html, sourceURL: nil)
        XCTAssertEqual(draft.title, "Pierogi ruskie")
        XCTAssertEqual(draft.servings, 8)
        XCTAssertEqual(draft.ingredients.count, 3)
        XCTAssertEqual(draft.instructions.count, 3)
        XCTAssertEqual(draft.caloriesPerServing, 320)
        XCTAssertEqual(draft.proteinPerServing, 10)
        XCTAssertEqual(draft.carbsPerServing, 55)
        XCTAssertEqual(draft.fatPerServing, 6)
    }

    func testParseHandlesHowToStepInstructions() throws {
        let json = """
            {
              "@type": "Recipe",
              "name": "X",
              "recipeIngredient": ["a"],
              "recipeInstructions": [
                {"@type": "HowToStep", "text": "Krok 1"},
                {"@type": "HowToStep", "name": "Krok 2"}
              ]
            }
            """
        let draft = try RecipeURLImporter().parse(html: Self.fixtureHTML(jsonLD: json), sourceURL: nil)
        XCTAssertEqual(draft.instructions, ["Krok 1", "Krok 2"])
    }

    func testParseHandlesGraphWrapper() throws {
        let json = """
            {
              "@context": "https://schema.org",
              "@graph": [
                {"@type": "WebPage", "name": "Blog page"},
                {
                  "@type": "Recipe",
                  "name": "Wrapped recipe",
                  "recipeIngredient": ["item"],
                  "recipeInstructions": "Krok jeden\\nKrok dwa"
                }
              ]
            }
            """
        let draft = try RecipeURLImporter().parse(html: Self.fixtureHTML(jsonLD: json), sourceURL: nil)
        XCTAssertEqual(draft.title, "Wrapped recipe")
        XCTAssertEqual(draft.instructions, ["Krok jeden", "Krok dwa"])
    }

    func testParseHandlesArrayTypeWithRecipe() throws {
        let json = """
            {
              "@type": ["Article", "Recipe"],
              "name": "Dual-typed",
              "recipeIngredient": []
            }
            """
        let draft = try RecipeURLImporter().parse(html: Self.fixtureHTML(jsonLD: json), sourceURL: nil)
        XCTAssertEqual(draft.title, "Dual-typed")
    }

    func testParseFailsWhenNoRecipeFound() {
        let json = """
            {"@type": "Article", "name": "No recipe here"}
            """
        XCTAssertThrowsError(
            try RecipeURLImporter().parse(html: Self.fixtureHTML(jsonLD: json), sourceURL: nil)
        ) { error in
            XCTAssertEqual(error as? RecipeURLImporter.ImportError, .noRecipeFound)
        }
    }

    func testParseFailsWhenNoJSONLDPresent() {
        XCTAssertThrowsError(
            try RecipeURLImporter().parse(html: "<html><body>no jsonld</body></html>", sourceURL: nil)
        ) { error in
            XCTAssertEqual(error as? RecipeURLImporter.ImportError, .noRecipeFound)
        }
    }

    // MARK: - Fetch path

    func testImportFromURLFetchesViaSession() async throws {
        let json = """
            {"@type": "Recipe", "name": "Fetched", "recipeIngredient": ["a"], "recipeYield": 4}
            """
        let html = Self.fixtureHTML(jsonLD: json)
        MockURLProtocol.handler = { request in
            guard
                let response = HTTPURLResponse(
                    url: request.url ?? URL(filePath: "/"),
                    statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil
                )
            else { fatalError("HTTPURLResponse init") }
            return (response, Data(html.utf8))
        }
        let session = MockURLProtocol.makeSession()
        let importer = RecipeURLImporter(session: session)
        let draft = try await importer.import(from: "https://example.com/recipe")
        XCTAssertEqual(draft.title, "Fetched")
        XCTAssertEqual(draft.servings, 4)
    }

    func testImportFailsForNon200() async throws {
        MockURLProtocol.handler = { request in
            guard
                let response = HTTPURLResponse(
                    url: request.url ?? URL(filePath: "/"),
                    statusCode: 503, httpVersion: "HTTP/1.1", headerFields: nil
                )
            else { fatalError("HTTPURLResponse init") }
            return (response, Data())
        }
        let importer = RecipeURLImporter(session: MockURLProtocol.makeSession())
        do {
            _ = try await importer.import(from: "https://example.com/down")
            XCTFail("expected fetchFailed")
        } catch RecipeURLImporter.ImportError.fetchFailed {
            // expected
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testImportRejectsInvalidURL() async {
        let importer = RecipeURLImporter()
        do {
            _ = try await importer.import(from: "not a url")
            XCTFail("expected invalidURL")
        } catch RecipeURLImporter.ImportError.invalidURL {
            // expected
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }
}
