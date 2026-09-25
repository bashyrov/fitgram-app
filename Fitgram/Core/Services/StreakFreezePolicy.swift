import Foundation

/// One place for the premium "streak freeze" rules so Today, services,
/// and notifications reason about the same state.
struct StreakFreezePolicy {
    static let maxAvailable = 2
    static let daysPerEarnedFreeze = 7

    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func canUseFreeze(streak: Streak?, now: Date, hasLoggedToday: Bool) -> Bool {
        guard let streak else { return false }
        guard streak.currentLength > 0, streak.freezesAvailable > 0 else { return false }
        guard !hasLoggedToday, !hasProtectedToday(streak: streak, now: now) else { return false }
        guard let lastProtectedDay = streak.lastLoggedDate.map({ calendar.startOfDay(for: $0) }) else {
            return false
        }
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: lastProtectedDay, to: today).day == 1
    }

    func hasProtectedToday(streak: Streak?, now: Date) -> Bool {
        guard let streak else { return false }
        let today = calendar.startOfDay(for: now)
        if let lastLog = streak.lastLoggedDate, calendar.isDate(lastLog, inSameDayAs: today) {
            return true
        }
        if let lastFreeze = streak.lastFreezeDate, calendar.isDate(lastFreeze, inSameDayAs: today) {
            return true
        }
        return false
    }

    @discardableResult
    func reconcile(_ streak: Streak, now: Date) -> Bool {
        guard let last = streak.lastLoggedDate else { return false }
        let lastDay = calendar.startOfDay(for: last)
        let today = calendar.startOfDay(for: now)
        let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        guard gap > 1, streak.currentLength != 0 else { return false }
        streak.currentLength = 0
        streak.lastLoggedDate = nil
        return true
    }

    @discardableResult
    func awardEarnedFreezes(_ streak: Streak) -> Bool {
        guard streak.currentLength > 0 else { return false }
        let milestoneLength = (streak.currentLength / Self.daysPerEarnedFreeze) * Self.daysPerEarnedFreeze
        guard milestoneLength > streak.lastFreezeAwardedLength else { return false }

        let earnedCount = (milestoneLength - streak.lastFreezeAwardedLength) / Self.daysPerEarnedFreeze
        let previousFreezes = streak.freezesAvailable
        streak.freezesAvailable = min(Self.maxAvailable, streak.freezesAvailable + earnedCount)
        streak.lastFreezeAwardedLength = milestoneLength
        return previousFreezes != streak.freezesAvailable
    }
}
