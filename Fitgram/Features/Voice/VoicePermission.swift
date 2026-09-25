import AVFoundation
import Foundation
import Speech

/// Voice input needs both speech-recognition + microphone access. We treat
/// the combination as a single permission gate so the UI only shows one
/// "needs permission" screen.
enum VoicePermission {
    enum Status: Sendable, Equatable {
        case authorized
        case denied
        case notDetermined
        case restricted
    }

    static var current: Status {
        let speech = SFSpeechRecognizer.authorizationStatus()
        let mic = AVAudioApplication.shared.recordPermission
        return combine(speech: speech, mic: mic)
    }

    static func request() async -> Status {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        let mic = await AVAudioApplication.requestRecordPermission()
        let micPermission: AVAudioApplication.recordPermission = mic ? .granted : .denied
        return combine(speech: speech, mic: micPermission)
    }

    private static func combine(
        speech: SFSpeechRecognizerAuthorizationStatus,
        mic: AVAudioApplication.recordPermission
    ) -> Status {
        if speech == .restricted { return .restricted }
        if speech == .denied || mic == .denied { return .denied }
        if speech == .notDetermined || mic == .undetermined { return .notDetermined }
        if speech == .authorized && mic == .granted { return .authorized }
        return .denied
    }
}
