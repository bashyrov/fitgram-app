import XCTest

@testable import Mealgram

@MainActor
final class OpenFoodFactsLookupTests: XCTestCase {
    private static let baseURL: URL = {
        guard let url = URL(string: "https://world.openfoodfacts.test") else {
            fatalError("static test base URL is invalid")
        }
        return url
    }()

    override func setUp() async throws {
        MockURLProtocol.reset()
    }

    override func tearDown() async throws {
        MockURLProtocol.reset()
    }

    // MARK: - Mapping

    func testMappingExtractsLocalizedPolishNameWhenAvailable() throws {
        let product = OFFProduct.fromJSON(
            #"""
            {
              "product_name": "Generic",
              "product_name_pl": "Twaróg półtłusty",
              "product_name_en": "Quark",
              "brands": "Piątnica, Mlekovita",
              "serving_quantity": 100,
              "image_url": "https://example.com/x.jpg",
              "nutriments": {
                "energy-kcal_100g": 132,
                "proteins_100g": 18.5,
                "carbohydrates_100g": 3.2,
                "fat_100g": 5
              }
            }
            """#)

        let mapped = try OpenFoodFactsLookup.makeProduct(from: product, barcode: "5901234")
        XCTAssertEqual(mapped.name, "Twaróg półtłusty")
        XCTAssertEqual(mapped.brand, "Piątnica")
        XCTAssertEqual(mapped.servingGrams, 100)
        XCTAssertEqual(mapped.nutrition.caloriesKcalPer100g, 132)
        XCTAssertEqual(mapped.nutrition.proteinPer100g, 18.5, accuracy: 0.001)
        XCTAssertEqual(mapped.imageURL?.absoluteString, "https://example.com/x.jpg")
    }

    func testMappingFallsBackToEnglishNameWhenPolishMissing() throws {
        let product = OFFProduct.fromJSON(
            #"""
            {
              "product_name_en": "Chicken breast",
              "nutriments": { "energy-kcal_100g": 165 }
            }
            """#)
        let mapped = try OpenFoodFactsLookup.makeProduct(from: product, barcode: "1")
        XCTAssertEqual(mapped.name, "Chicken breast")
    }

    func testMissingNutritionThrows() {
        let product = OFFProduct.fromJSON(
            #"""
            { "product_name": "Empty", "nutriments": {} }
            """#)
        XCTAssertThrowsError(try OpenFoodFactsLookup.makeProduct(from: product, barcode: "1")) { error in
            XCTAssertEqual(error as? BarcodeLookupError, .missingNutrition)
        }
    }

    func testNumericFieldsAcceptStringFormat() throws {
        let product = OFFProduct.fromJSON(
            #"""
            {
              "product_name": "Cola",
              "serving_quantity": "330",
              "nutriments": {
                "energy-kcal_100g": "42",
                "carbohydrates_100g": "10,6"
              }
            }
            """#)
        let mapped = try OpenFoodFactsLookup.makeProduct(from: product, barcode: "9")
        XCTAssertEqual(mapped.servingGrams, 330)
        XCTAssertEqual(mapped.nutrition.caloriesKcalPer100g, 42)
        XCTAssertEqual(mapped.nutrition.carbsPer100g, 10.6, accuracy: 0.001)
    }

    // MARK: - End-to-end

    func testLookupSuccessRoundTripsThroughURLSession() async throws {
        let fallbackURL = Self.baseURL
        let payload = #"""
            {
              "status": 1,
              "product": {
                "product_name_pl": "Pomidor",
                "brands": "BIO Planet",
                "serving_quantity": 200,
                "nutriments": {
                  "energy-kcal_100g": 18,
                  "proteins_100g": 0.9,
                  "carbohydrates_100g": 3.9,
                  "fat_100g": 0.2
                }
              }
            }
            """#
        MockURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v2/product/12345.json")
            return MockURLProtocol.makeResponse(
                url: request.url ?? fallbackURL,
                status: 200,
                body: Data(payload.utf8)
            )
        }
        let session = MockURLProtocol.makeSession()
        let lookup = OpenFoodFactsLookup(session: session, baseURL: Self.baseURL)
        let product = try await lookup.lookup(barcode: "12345")
        XCTAssertEqual(product.name, "Pomidor")
        XCTAssertEqual(product.brand, "BIO Planet")
        XCTAssertEqual(product.servingGrams, 200)
    }

    func testLookupReturnsNotFoundOnStatusZero() async throws {
        let fallbackURL = Self.baseURL
        let payload = #"{"status":0,"product":null}"#
        MockURLProtocol.handler = { request in
            MockURLProtocol.makeResponse(
                url: request.url ?? fallbackURL,
                status: 200,
                body: Data(payload.utf8)
            )
        }
        let lookup = OpenFoodFactsLookup(session: MockURLProtocol.makeSession(), baseURL: Self.baseURL)
        do {
            _ = try await lookup.lookup(barcode: "00000")
            XCTFail("Expected notFound")
        } catch BarcodeLookupError.notFound {
            // expected
        }
    }

    func testLookupReturnsNotFoundOn404() async throws {
        let fallbackURL = Self.baseURL
        MockURLProtocol.handler = { request in
            MockURLProtocol.makeResponse(url: request.url ?? fallbackURL, status: 404, body: nil)
        }
        let lookup = OpenFoodFactsLookup(session: MockURLProtocol.makeSession(), baseURL: Self.baseURL)
        do {
            _ = try await lookup.lookup(barcode: "00000")
            XCTFail("Expected notFound")
        } catch BarcodeLookupError.notFound {
            // expected
        }
    }
}

// MARK: - Test helper

extension OFFProduct {
    static func fromJSON(_ string: String) -> OFFProduct {
        let data = Data(string.utf8)
        do {
            return try JSONDecoder().decode(OFFProduct.self, from: data)
        } catch {
            fatalError("Bad fixture: \(error)")
        }
    }
}
