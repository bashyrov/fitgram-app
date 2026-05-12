import XCTest

@testable import Mealgram

@MainActor
final class FoodItemEditorTests: XCTestCase {
    func testParseDoubleAcceptsCommaDecimal() {
        XCTAssertEqual(FoodItemEditorSheet.parseDouble("12,5"), 12.5)
        XCTAssertEqual(FoodItemEditorSheet.parseDouble("12.5"), 12.5)
        XCTAssertEqual(FoodItemEditorSheet.parseDouble("42"), 42)
        XCTAssertNil(FoodItemEditorSheet.parseDouble("foo"))
    }

    func testFormatRoundsWholeNumbersWithoutDecimal() {
        XCTAssertEqual(FoodItemEditorSheet.format(180), "180")
        XCTAssertEqual(FoodItemEditorSheet.format(12.5), "12.5")
    }

    func testAddingModeIdentityIsStableAcrossSelf() {
        let mode: FoodItemEditorSheet.Mode = .adding
        XCTAssertEqual(mode.id, "adding")
    }

    func testEditingModeIdentityIncludesItemUUID() {
        let item = ScanResult.DetectedItem(
            id: UUID(uuidString: "DEADBEEF-DEAD-BEEF-DEAD-BEEFDEADBEEF") ?? UUID(),
            name: "X",
            quantityGrams: 100,
            caloriesKcal: 10,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            confidence: 1
        )
        let mode: FoodItemEditorSheet.Mode = .editing(item)
        XCTAssertTrue(mode.id.contains(item.id.uuidString))
    }
}
