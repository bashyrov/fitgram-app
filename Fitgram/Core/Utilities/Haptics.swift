import UIKit

/// Thin convenience wrapper over `UIFeedbackGenerator`. Centralised so
/// every "tactile moment" in the app uses the same vocabulary — success
/// for completion, warning for destructive paths, impact for one-tap
/// affirmations.
///
/// Each call is fire-and-forget: we don't pre-prepare the generator
/// (the cost of skipping prepare() is ~150 ms first-time latency, fine
/// for human-paced UX). The methods are nonisolated so they're cheap to
/// call from anywhere.
@MainActor
enum Haptics {
    static func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    static func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
