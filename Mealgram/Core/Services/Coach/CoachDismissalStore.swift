import Foundation

/// Tracks which Ola insights the user has hidden for the current day.
/// Backed by UserDefaults — the cardinality is small (a handful per day)
/// and the data is fully derivable from the rule engine, so we don't
/// need a SwiftData table just for this. Keys are scoped to the
/// calendar day so the dismissal automatically expires at midnight.
struct CoachDismissalStore {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
    }

    func dismiss(headline: String) {
        var dismissed = todaysDismissed()
        dismissed.insert(headline)
        defaults.set(Array(dismissed), forKey: key())
    }

    func isDismissed(headline: String) -> Bool {
        todaysDismissed().contains(headline)
    }

    /// Removes every dismissal for the current day. Used by tests + the
    /// "reset coach" path in Profile if we ever add one.
    func clearToday() {
        defaults.removeObject(forKey: key())
    }

    /// Visible for tests — the set the store currently holds for today.
    func todaysDismissed() -> Set<String> {
        let stored = (defaults.array(forKey: key()) as? [String]) ?? []
        return Set(stored)
    }

    private func key() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = calendar.timeZone
        return "coach.dismissed.\(formatter.string(from: calendar.startOfDay(for: now())))"
    }
}
