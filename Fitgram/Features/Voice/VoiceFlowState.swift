import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class VoiceFlowState {
    enum Stage: Equatable {
        case checkingPermission
        case needsPermission(VoicePermission.Status)
        case idle
        case listening
        case finished(transcript: String)
        case error(message: String)
    }

    private(set) var stage: Stage = .checkingPermission
    private(set) var partialTranscript: String = ""

    private let session: VoiceCaptureSession
    private let mealSaver: any MealSaving
    private let parser: VoiceMealParser

    init(
        session: VoiceCaptureSession,
        mealSaver: any MealSaving,
        parser: VoiceMealParser = VoiceMealParser()
    ) {
        self.session = session
        self.mealSaver = mealSaver
        self.parser = parser
    }

    func start() async {
        stage = .checkingPermission
        let status = await VoicePermission.request()
        guard status == .authorized else {
            stage = .needsPermission(status)
            return
        }
        guard session.isAvailable else {
            stage = .error(message: "Speech recognition is not available on this device.")
            return
        }
        stage = .idle
    }

    func beginListening() {
        partialTranscript = ""
        do {
            try session.start(
                onPartial: { [weak self] partial in
                    self?.partialTranscript = partial
                },
                onFinal: { [weak self] final in
                    self?.partialTranscript = final
                    self?.stage = .finished(transcript: final)
                }
            )
            stage = .listening
        } catch {
            Logger.ui.error("Voice start failed: \(String(describing: error))")
            stage = .error(message: "Something went wrong. Try again.")
        }
    }

    /// User taps the mic again to stop early. We surface whatever partial
    /// transcript we have so the editor sheet pre-fills the name.
    func stopListening() {
        session.stop()
        stage = .finished(transcript: partialTranscript)
    }

    func reset() {
        session.stop()
        partialTranscript = ""
        stage = .idle
    }

    func commit(items: [FoodItem]) throws {
        let suggested = Self.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let entry = MealEntry(mealType: suggested, source: .voice, items: items)
        try mealSaver.save(meal: entry)
    }

    static func suggestedMealType(forHour hour: Int) -> MealType {
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}
