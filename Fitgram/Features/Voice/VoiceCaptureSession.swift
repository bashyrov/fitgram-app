import AVFoundation
import Foundation
import OSLog
import Speech

/// Live speech-to-text in Polish via `SFSpeechRecognizer`. Live transcript
/// streams up through the `onPartial` callback; the final result lands in
/// `onFinal`. Heavily-stripped — recognition restart, dialect fallback,
/// and AI-parsing of the transcript ship in later milestones.
@MainActor
final class VoiceCaptureSession {
    enum CaptureFailure: Error {
        case unavailable
        case audioEngineFailed(String)
        case recognizerFailed(String)
    }

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    /// Live loudness for the waveform, fed from the same tap as recognition.
    let meter = VoiceLevelMeter()

    init(locale: Locale = Locale.current) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Begins capturing. `onPartial` fires with each interim result;
    /// `onFinal` fires once the recogniser is confident or the caller
    /// stops the session.
    func start(
        onPartial: @escaping @MainActor (String) -> Void,
        onFinal: @escaping @MainActor (String) -> Void
    ) throws {
        guard let recognizer, recognizer.isAvailable else {
            throw CaptureFailure.unavailable
        }
        try configureAudioSession()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = false
        self.request = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        meter.reset()
        inputNode.installTap(
            onBus: 0, bufferSize: 1024, format: format,
            block: Self.makeTap(request: request, meter: meter))

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            throw CaptureFailure.audioEngineFailed(error.localizedDescription)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        onFinal(transcript)
                        self.stop()
                    } else {
                        onPartial(transcript)
                    }
                }
                if let error {
                    Logger.ui.error("Speech recognition failed: \(String(describing: error))")
                    self.stop()
                }
            }
        }
    }

    /// Built outside the main actor: the tap runs on the audio render thread.
    nonisolated private static func makeTap(
        request: SFSpeechAudioBufferRecognitionRequest,
        meter: VoiceLevelMeter
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            let level = VoiceLevelMeter.normalizedLevel(of: buffer)
            Task { @MainActor in meter.push(level) }
        }
    }

    /// Stops capture and finalises any pending recognition. Idempotent.
    func stop() {
        meter.reset()
        audioEngine.inputNode.removeTap(onBus: 0)
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw CaptureFailure.audioEngineFailed(error.localizedDescription)
        }
    }
}
