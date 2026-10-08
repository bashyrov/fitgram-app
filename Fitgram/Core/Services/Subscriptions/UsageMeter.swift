import Foundation
import OSLog
import Observation

/// Quota tracker for premium-gated AI features. Photo, voice, meal refreshes
/// and per-product nutrition lookups share one weekly free pool (Mon–Sun,
/// local time); barcode is intentionally non-AI and unlimited. The hidden AI
/// safety counter stays daily.
@MainActor
@Observable
final class UsageMeter {
    enum Kind: String, CaseIterable, Sendable {
        case photoScan
        case barcodeScan
        case voiceEntry
        case mealAIRefresh
        case productNutritionLookup
        case olaChef
        case coachDebrief

        fileprivate var storageKey: String {
            switch self {
            case .photoScan, .voiceEntry, .mealAIRefresh, .productNutritionLookup:
                return "usage.aiWeekly"
            case .barcodeScan:
                return "usage.barcodeScan"
            case .olaChef:
                return "usage.olaChef"
            case .coachDebrief:
                return "usage.coachDebrief"
            }
        }

        fileprivate var sharedKinds: [Kind] {
            switch self {
            case .photoScan, .voiceEntry, .mealAIRefresh, .productNutritionLookup:
                return Kind.weeklyPool
            case .barcodeScan:
                return [.barcodeScan]
            case .olaChef:
                return [.olaChef]
            case .coachDebrief:
                return [.coachDebrief]
            }
        }

        fileprivate static let weeklyPool: [Kind] = [.photoScan, .voiceEntry, .mealAIRefresh, .productNutritionLookup]

        /// Counted per ISO week instead of per day.
        fileprivate var isWeekly: Bool { Kind.weeklyPool.contains(self) }

        fileprivate var isAIBacked: Bool {
            switch self {
            case .photoScan, .voiceEntry, .mealAIRefresh, .productNutritionLookup, .olaChef, .coachDebrief:
                return true
            case .barcodeScan:
                return false
            }
        }
    }

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let now: () -> Date

    private(set) var counts: [Kind: Int] = [:]
    private var cachedDayToken: String
    private var cachedWeekToken: String

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .fitgramLocalDay,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.cachedDayToken = UsageMeter.dayToken(for: now(), calendar: calendar)
        self.cachedWeekToken = UsageMeter.weekToken(for: now(), calendar: calendar)
        refreshCounts()
    }

    /// Returns the number of uses already consumed in the current period
    /// (this week for the shared AI pool, today otherwise).
    func used(_ kind: Kind) -> Int {
        refreshIfDayChanged()
        return counts[kind] ?? defaults.integer(forKey: perDayKey(for: kind))
    }

    /// Returns how many uses remain, given a cap (`nil` = unlimited).
    func remaining(_ kind: Kind, cap: Int?) -> Int? {
        let safetyRemaining = aiSafetyRemaining(for: kind)
        guard let cap else { return nil }
        return min(max(0, cap - used(kind)), safetyRemaining.value)
    }

    func canUse(_ kind: Kind, cap: Int?) -> Bool {
        // A nil feature cap means Pro/unlimited in the UI. The authoritative
        // 60-request abuse ceiling lives on the Worker, which can return the
        // dedicated temporary-unavailable state instead of a wrong paywall.
        guard let cap else { return true }
        guard canUseAISafetyCap(kind) else { return false }
        return used(kind) < cap
    }

    /// Records a use. Feature-specific counters are no-ops when `cap` is nil
    /// (premium), but the hidden AI safety counter always records AI-backed
    /// requests. Returns the new remaining count so callers can show a toast.
    @discardableResult
    func record(_ kind: Kind, cap: Int?) -> Int? {
        refreshIfDayChanged()
        if kind.isAIBacked {
            let safetyKey = aiSafetyPerDayKey()
            let safetyNew = defaults.integer(forKey: safetyKey) + 1
            defaults.set(safetyNew, forKey: safetyKey)
        }
        guard cap != nil else { return nil }
        let key = perDayKey(for: kind)
        let new = defaults.integer(forKey: key) + 1
        defaults.set(new, forKey: key)
        for sharedKind in kind.sharedKinds {
            counts[sharedKind] = new
        }
        Logger.persistence.notice(
            "UsageMeter +1 \(kind.rawValue, privacy: .public) → \(new, privacy: .public)"
        )
        return cap.map { max(0, $0 - new) }
    }

    /// Test-only — clear every kind for the current period.
    func resetForTesting() {
        refreshIfDayChanged()
        for kind in Kind.allCases {
            defaults.removeObject(forKey: perDayKey(for: kind))
            counts[kind] = 0
        }
        defaults.removeObject(forKey: aiSafetyPerDayKey())
    }

    func reloadAfterAccountDeletion() {
        cachedDayToken = UsageMeter.dayToken(for: now(), calendar: calendar)
        cachedWeekToken = UsageMeter.weekToken(for: now(), calendar: calendar)
        refreshCounts()
    }

    // MARK: - Private

    private func refreshCounts() {
        for kind in Kind.allCases {
            counts[kind] = defaults.integer(forKey: perDayKey(for: kind))
        }
    }

    private func perDayKey(for kind: Kind) -> String {
        "\(kind.storageKey).\(kind.isWeekly ? cachedWeekToken : cachedDayToken)"
    }

    private func aiSafetyPerDayKey() -> String {
        "usage.aiSafety.\(cachedDayToken)"
    }

    private func canUseAISafetyCap(_ kind: Kind) -> Bool {
        guard kind.isAIBacked else { return true }
        return defaults.integer(forKey: aiSafetyPerDayKey()) < FreeTierLimits.aiRequestsSafetyCapPerDay
    }

    private func aiSafetyRemaining(for kind: Kind) -> (value: Int, isLimited: Bool) {
        guard kind.isAIBacked else { return (Int.max, false) }
        let used = defaults.integer(forKey: aiSafetyPerDayKey())
        return (max(0, FreeTierLimits.aiRequestsSafetyCapPerDay - used), true)
    }

    private func refreshIfDayChanged() {
        let token = Self.dayToken(for: now(), calendar: calendar)
        guard token != cachedDayToken else { return }
        cachedDayToken = token
        cachedWeekToken = Self.weekToken(for: now(), calendar: calendar)
        refreshCounts()
    }

    private static func weekToken(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(comps.yearForWeekOfYear ?? 0)-W\(String(format: "%02d", comps.weekOfYear ?? 0))"
    }

    private static func dayToken(for date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        let day = comps.day ?? 0
        return "\(year)-\(String(format: "%02d", month))-\(String(format: "%02d", day))"
    }
}

extension Calendar {
    /// Local calendar day for daily free-tier quotas. Uses the user's
    /// current time zone so limits reset at their local midnight.
    static var fitgramLocalDay: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2  // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}
