import AVFoundation
import Foundation
import Observation

/// Rolling microphone loudness for the voice waveform. The capture tap pushes
/// one normalised level (0…1) per audio buffer (~45 per second); the view
/// draws the most recent `barCount` values, newest on the right, so the bars
/// move exactly with what the microphone hears.
@MainActor
@Observable
final class VoiceLevelMeter {
    static let barCount = 17

    private(set) var levels: [Double] = Array(repeating: 0, count: VoiceLevelMeter.barCount)

    func push(_ level: Double) {
        levels.removeFirst()
        levels.append(min(1, max(0, level)))
    }

    func reset() {
        levels = Array(repeating: 0, count: Self.barCount)
    }

    /// RMS of the buffer's first channel mapped from -50 dB (silence) … -10 dB
    /// (loud speech) onto 0…1. Runs on the audio render thread.
    nonisolated static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<frames {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(frames))
        return normalized(decibels: 20 * log10(max(rms, 1e-7)))
    }

    nonisolated static func normalized(decibels: Float) -> Double {
        let floor: Float = -50
        let ceiling: Float = -10
        return Double(min(1, max(0, (decibels - floor) / (ceiling - floor))))
    }
}
