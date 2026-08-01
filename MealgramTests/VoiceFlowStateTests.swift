import XCTest

@testable import Mealgram

@MainActor
final class VoiceFlowStateTests: XCTestCase {
    private var saver: SpyMealSaver!

    override func setUp() async throws {
        saver = SpyMealSaver()
    }

    func testSuggestedMealTypeByHour() {
        XCTAssertEqual(VoiceFlowState.suggestedMealType(forHour: 8), .breakfast)
        XCTAssertEqual(VoiceFlowState.suggestedMealType(forHour: 13), .lunch)
        XCTAssertEqual(VoiceFlowState.suggestedMealType(forHour: 19), .dinner)
        XCTAssertEqual(VoiceFlowState.suggestedMealType(forHour: 23), .snack)
    }

    func testCommitPersistsItemsAsMealEntry() throws {
        let state = VoiceFlowState(session: VoiceCaptureSession(), mealSaver: saver)
        let item = FoodItem(name: "Owsianka z malinami", quantityGrams: 250, caloriesKcal: 320)
        try state.commit(items: [item])
        let saved = try XCTUnwrap(saver.saved)
        XCTAssertEqual(saved.source, .voice)
        XCTAssertEqual(saved.items.count, 1)
        XCTAssertEqual(saved.items.first?.name, "Owsianka z malinami")
    }
}
