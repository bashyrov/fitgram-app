import XCTest

@testable import Mealgram

@MainActor
final class BarcodeFlowStateTests: XCTestCase {
    private var saver: SpyMealSaver!

    override func setUp() async throws {
        saver = SpyMealSaver()
    }

    private func makeState(
        lookupResult: Result<BarcodeProduct, Error>
    ) -> BarcodeFlowState {
        BarcodeFlowState(
            captureSession: BarcodeCaptureSession(),
            lookup: SpyLookup(result: lookupResult),
            mealSaver: saver
        )
    }

    func testSuggestedMealTypeByHour() {
        XCTAssertEqual(BarcodeFlowState.suggestedMealType(forHour: 8), .breakfast)
        XCTAssertEqual(BarcodeFlowState.suggestedMealType(forHour: 13), .lunch)
        XCTAssertEqual(BarcodeFlowState.suggestedMealType(forHour: 20), .dinner)
        XCTAssertEqual(BarcodeFlowState.suggestedMealType(forHour: 2), .snack)
    }

    func testBarcodeProductMapsToScanResultWithScaledNutrition() {
        let product = BarcodeProduct(
            barcode: "111",
            name: "Test",
            brand: "Mealgram",
            imageURL: nil,
            nutrition: .init(
                caloriesKcalPer100g: 200,
                proteinPer100g: 10,
                carbsPer100g: 30,
                fatPer100g: 5,
                fiberPer100g: nil
            ),
            servingGrams: 50
        )
        let scan = product.asScanResult(suggestedMealType: .snack)
        XCTAssertEqual(scan.items.count, 1)
        let item = scan.items[0]
        XCTAssertEqual(item.quantityGrams, 50)
        XCTAssertEqual(item.caloriesKcal, 100, accuracy: 0.001)
        XCTAssertEqual(item.proteinGrams, 5, accuracy: 0.001)
        XCTAssertEqual(item.confidence, 0.99, accuracy: 0.001)
        XCTAssertEqual(scan.rawAINotes, "Marka: Mealgram")
    }

    func testCommitPersistsThroughMealSaver() throws {
        let product = BarcodeProduct(
            barcode: "222",
            name: "Pomidor",
            brand: nil,
            imageURL: nil,
            nutrition: .init(
                caloriesKcalPer100g: 18,
                proteinPer100g: 0.9,
                carbsPer100g: 3.9,
                fatPer100g: 0.2,
                fiberPer100g: nil
            ),
            servingGrams: 100
        )
        let state = makeState(lookupResult: .success(product))
        try state.commit(result: product, portionMultiplier: 2.0)

        let saved = try XCTUnwrap(saver.saved)
        XCTAssertEqual(saved.source, .barcode)
        XCTAssertEqual(saved.portionMultiplier, 2.0)
        XCTAssertEqual(saved.items.first?.name, "Pomidor")
    }
}

private final class SpyLookup: BarcodeLookupService, @unchecked Sendable {
    var result: Result<BarcodeProduct, Error>
    init(result: Result<BarcodeProduct, Error>) { self.result = result }
    func lookup(barcode _: String) async throws -> BarcodeProduct {
        try result.get()
    }
}
