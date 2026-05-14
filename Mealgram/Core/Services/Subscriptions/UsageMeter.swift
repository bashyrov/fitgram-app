import Foundation
import Observation
import OSLog

/// Per-week quota tracker for premium-gated AI features. State lives in
/// UserDefaults under a week-key (ISO yearWeek), so rollover happens
/// automatically at the start of each ISO week without a background
/// task. Observable so views re-render the "X / Y left" hint.
@MainActor
@Observable
final class UsageMeter {
    enum Kind: String, CaseIterable, Sendable {
        case photoScan
        case barcodeScan
        case voiceEntry
        case coachDebrief

        fileprivate var storageKey: String {
            "usage.\(rawValue)"
        }
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    private(set) var counts: [Kind: Int] = [:]

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .iso8601Monday,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        refreshCounts()
    }

    /// Returns the number of uses already consumed in the current ISO week.
    func used(_ kind: Kind) -> Int {
        counts[kind] ?? 0
    }

    /// Returns how many uses remain, given a cap (`nil` = unlimited).
    func remaining(_ kind: Kind, cap: Int?) -> Int? {
        guard let cap else { return nil }
        return max(0, cap - used(kind))
    }

    func canUse(_ kind: Kind, cap: Int?) -> Bool {
        guard let cap else { return true }
        return used(kind) < cap
    }

    /// Records a use. No-op when `cap` is nil (premium). Returns the new
    /// remaining count so callers can show a toast.
    @discardableResult
    func record(_ kind: Kind, cap: Int?) -> Int? {
        guard cap != nil else { return nil }
        let key = perWeekKey(for: kind)
        let new = defaults.integer(forKey: key) + 1
        defaults.set(new, forKey: key)
        counts[kind] = new
        Logger.persistence.notice(
            "UsageMeter +1 \(kind.rawValue, privacy: .public) → \(new, privacy: .public)"
        )
        return cap.map { max(0, $0 - new) }
    }

    /// Test-only — clear every kind for the current week.
    func resetForTesting() {
        for kind in Kind.allCases {
            defaults.removeObject(forKey: perWeekKey(for: kind))
            counts[kind] = 0
        }
    }

    // MARK: - Private

    private func refreshCounts() {
        for kind in Kind.allCases {
            counts[kind] = defaults.integer(forKey: perWeekKey(for: kind))
        }
    }

    private func perWeekKey(for kind: Kind) -> String {
        "\(kind.storageKey).\(currentWeekToken)"
    }

    private var currentWeekToken: String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now())
        let year = comps.yearForWeekOfYear ?? 0
        let week = comps.weekOfYear ?? 0
        return "\(year)W\(String(format: "%02d", week))"
    }
}

extension Calendar {
    /// ISO 8601 Monday-anchored — matches Polish week conventions and
    /// the way the Weekly Debrief already groups data.
    static let iso8601Monday: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2  // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }()
}
