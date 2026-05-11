import Foundation
import OSLog
import SwiftData

/// Daily logging streak. Pure logic, parameterized by a `Clock`-style date
/// source so tests can pin the "now" value.
@MainActor
final class StreakService {
    private let container: ModelContainer
    private let now: () -> Date
    private let calendar: Calendar

    init(
        container: ModelContainer,
        now: @escaping () -> Date = Date.init,
        calendar: Calendar = .current
    ) {
        self.container = container
        self.now = now
        self.calendar = calendar
    }

    /// Returns (and persists if needed) the streak row for the given user.
    /// Idempotent.
    func currentStreak(for userRemoteID: String) throws -> Streak {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        if let existing = try context.fetch(descriptor).first {
            return existing
        }
        let fresh = Streak(userRemoteID: userRemoteID)
        context.insert(fresh)
        try context.save()
        return fresh
    }

    /// Call after a meal is saved. Bumps the streak on a fresh day, leaves
    /// it untouched if the user already logged today.
    func registerLog(for userRemoteID: String) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        let streak: Streak
        if let existing = try context.fetch(descriptor).first {
            streak = existing
        } else {
            streak = Streak(userRemoteID: userRemoteID)
            context.insert(streak)
        }
        let today = calendar.startOfDay(for: now())
        if let last = streak.lastLoggedDate.map({ calendar.startOfDay(for: $0) }) {
            switch calendar.dateComponents([.day], from: last, to: today).day ?? 0 {
            case 0:
                // Already logged today — keep streak as is, just bump last
                // logged time to "now" so we know the user is active.
                streak.lastLoggedDate = now()
            case 1:
                streak.currentLength += 1
                streak.longestLength = max(streak.longestLength, streak.currentLength)
                streak.lastLoggedDate = now()
            default:
                // More than one day gap — reset.
                Logger.persistence.notice("Streak reset for \(userRemoteID, privacy: .private)")
                streak.currentLength = 1
                streak.longestLength = max(streak.longestLength, 1)
                streak.lastLoggedDate = now()
            }
        } else {
            streak.currentLength = 1
            streak.longestLength = max(streak.longestLength, 1)
            streak.lastLoggedDate = now()
        }
        try context.save()
    }

    /// Use a freeze to bridge a missed day. Returns `true` if a freeze was
    /// available and consumed. Streak freeze is a premium item (Milestone
    /// 1.10 wires the entitlement).
    @discardableResult
    func consumeFreeze(for userRemoteID: String) throws -> Bool {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        guard let streak = try context.fetch(descriptor).first, streak.freezesAvailable > 0 else {
            return false
        }
        streak.freezesAvailable -= 1
        streak.lastLoggedDate = now()
        try context.save()
        return true
    }
}
