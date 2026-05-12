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

    init(session: VoiceCaptureSession, mealSaver: any MealSaving) {
        self.session = session
        self.mealSaver = mealSaver
    }

    func start() async {
        stage = .checkingPermission
        let status = await VoicePermission.request()
        guard status == .authorized else {
            stage = .needsPermission(status)
            return
        }
        guard session.isAvailable else {
            stage = .error(message: "Rozpoznawanie mowy nie jest dostępne na tym urządzeniu.")
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
            stage = .error(message: error.localizedDescription)
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

    func commit(transcript: String) throws {
        // Without AI parsing the transcript is a free-form name. The user
        // can refine grams + macros via the standard editor in the next
        // pass; for now we save a 1-item placeholder.
        let item = FoodItem(
            name: transcript.trimmingCharacters(in: .whitespacesAndNewlines),
            quantityGrams: 100,
            caloriesKcal: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0
        )
        let suggested = Self.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        let entry = MealEntry(mealType: suggested, source: .voice, items: [item])
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
