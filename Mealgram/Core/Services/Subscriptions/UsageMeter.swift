import Foundation
import OSLog
import Observation

/// Daily quota tracker for premium-gated AI features. Photo and voice share
/// the saved-meal AI budget; barcode is intentionally non-AI and unlimited.
/// Meal refreshes and per-product nutrition lookups have their own pools.
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
            case .photoScan, .voiceEntry:
                return "usage.aiLoggedMeal"
            case .barcodeScan:
                return "usage.barcodeScan"
            case .mealAIRefresh:
                return "usage.aiMealRefresh"
            case .productNutritionLookup:
                return "usage.aiProductNutrition"
            case .olaChef:
                return "usage.olaChef"
            case .coachDebrief:
                return "usage.coachDebrief"
            }
        }

        fileprivate var sharedKinds: [Kind] {
            switch self {
            case .photoScan, .voiceEntry:
                return [.photoScan, .voiceEntry]
            case .barcodeScan:
                return [.barcodeScan]
            case .mealAIRefresh:
                return [.mealAIRefresh]
            case .productNutritionLookup:
                return [.productNutritionLookup]
            case .olaChef:
                return [.olaChef]
            case .coachDebrief:
                return [.coachDebrief]
            }
        }

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

    init(
        defaults: UserDefaults = .standard,
        calendar: Calendar = .mealgramLocalDay,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.calendar = calendar
        self.now = now
        self.cachedDayToken = UsageMeter.dayToken(for: now(), calendar: calendar)
        refreshCounts()
    }

    /// Returns the number of AI uses already consumed today.
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
        guard canUseAISafetyCap(kind) else { return false }
        guard let cap else { return true }
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
        for aiKind in kind.sharedKinds {
            counts[aiKind] = new
        }
        Logger.persistence.notice(
            "UsageMeter +1 \(kind.rawValue, privacy: .public) → \(new, privacy: .public)"
        )
        return cap.map { max(0, $0 - new) }
    }

    /// Test-only — clear every kind for today.
    func resetForTesting() {
        refreshIfDayChanged()
        for kind in Kind.allCases {
            defaults.removeObject(forKey: perDayKey(for: kind))
            counts[kind] = 0
        }
        defaults.removeObject(forKey: aiSafetyPerDayKey())
    }

    // MARK: - Private

    private func refreshCounts() {
        for kind in Kind.allCases {
            counts[kind] = defaults.integer(forKey: perDayKey(for: kind))
        }
    }

    private func perDayKey(for kind: Kind) -> String {
        "\(kind.storageKey).\(cachedDayToken)"
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
        refreshCounts()
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
    static var mealgramLocalDay: Calendar {
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2  // Monday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}
