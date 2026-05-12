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

    func testCommitPersistsTranscriptAsMealEntry() throws {
        let state = VoiceFlowState(session: VoiceCaptureSession(), mealSaver: saver)
        try state.commit(transcript: "  zjadłam ovsiankę z malinami  ")
        let saved = try XCTUnwrap(saver.saved)
        XCTAssertEqual(saved.source, .voice)
        XCTAssertEqual(saved.items.count, 1)
        XCTAssertEqual(saved.items.first?.name, "zjadłam ovsiankę z malinami")
    }
}
