import XCTest

@testable import Mealgram

@MainActor
final class ScanStateTests: XCTestCase {
    func testSuggestedMealTypeMapsByHour() {
        XCTAssertEqual(ScanState.suggestedMealType(forHour: 8), .breakfast)
        XCTAssertEqual(ScanState.suggestedMealType(forHour: 12), .lunch)
        XCTAssertEqual(ScanState.suggestedMealType(forHour: 19), .dinner)
        XCTAssertEqual(ScanState.suggestedMealType(forHour: 23), .snack)
        XCTAssertEqual(ScanState.suggestedMealType(forHour: 3), .snack)
    }

    func testMockDetectorReturnsFixture() async throws {
        let detector = MockFoodDetector(latency: .zero)
        let result = try await detector.detect(from: Data([0xFF, 0xD8]), suggestedMealType: nil)
        XCTAssertEqual(result.items.count, 3)
        XCTAssertEqual(result.suggestedMealType, .lunch)
        XCTAssertGreaterThan(result.totalCalories, 0)
    }

    func testMockDetectorOverridesMealTypeWhenSuggested() async throws {
        let detector = MockFoodDetector(latency: .zero)
        let result = try await detector.detect(from: Data([0xFF]), suggestedMealType: .breakfast)
        XCTAssertEqual(result.suggestedMealType, .breakfast)
    }

    func testCommitWritesEntryThroughSaver() throws {
        let saver = SpyMealSaver()
        let state = ScanState(
            captureSession: CameraCaptureSession(),
            detector: MockFoodDetector(),
            mealSaver: saver
        )
        let result = ScanResult.defaultFixture

        try state.commit(result: result, portionMultiplier: 0.75)

        let savedMeal = try XCTUnwrap(saver.saved)
        XCTAssertEqual(savedMeal.source, .photoScan)
        XCTAssertEqual(savedMeal.mealType, .lunch)
        XCTAssertEqual(savedMeal.items.count, result.items.count)
        XCTAssertEqual(savedMeal.portionMultiplier, 0.75, accuracy: 0.001)
    }
}

final class SpyMealSaver: MealSaving, @unchecked Sendable {
    private(set) var saved: MealEntry?
    func save(meal: MealEntry) throws {
        saved = meal
    }
}
