import Foundation
import Observation

/// One-shot delivery channel for newly-unlocked achievements. The save
/// path pushes definitions in; the top-level scene observes and renders a
/// banner. The bus is process-local — it does not persist.
@MainActor
@Observable
final class AchievementUnlockBus {
    private(set) var queue: [AchievementDefinition] = []

    var current: AchievementDefinition? { queue.first }

    func push(_ unlocks: [AchievementDefinition]) {
        queue.append(contentsOf: unlocks)
    }

    func consume() {
        guard !queue.isEmpty else { return }
        queue.removeFirst()
    }
}
