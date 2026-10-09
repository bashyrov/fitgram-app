import XCTest

@testable import Fitgram

@MainActor
final class FoodMatchIndexTests: XCTestCase {
    private func food(_ name: String, translations: [String: String] = [:]) -> Food {
        let food = Food(name: name, caloriesKcalPer100g: 100)
        if !translations.isEmpty, let data = try? JSONEncoder().encode(translations) {
            food.localizationsJSON = String(data: data, encoding: .utf8)
        }
        return food
    }

    func testMatchesLikeNormalizerAcrossTranslations() {
        let catalog = [
            food("Pierogi ruskie"),
            food("Żurek", translations: ["ru": "Журек", "en": "Sour rye soup"]),
            food("Kotlet schabowy"),
        ]
        let index = FoodMatchIndex()
        for query in ["zurek", "Sour rye soup", "schabowy", "журек", "pizza"] {
            let expected = catalog.first { FoodNameNormalizer.isMatch(query: query, food: $0) }
            XCTAssertTrue(index.firstMatch(for: query, in: catalog) === expected, query)
        }
    }

    func testRebuildsWhenCatalogGrows() {
        var catalog = [food("Pierogi ruskie")]
        let index = FoodMatchIndex()
        XCTAssertNil(index.firstMatch(for: "Hummus", in: catalog))
        catalog.append(food("Hummus"))
        XCTAssertEqual(index.firstMatch(for: "Hummus", in: catalog)?.name, "Hummus")
    }
}
