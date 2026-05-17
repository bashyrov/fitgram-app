import ActivityKit
import Foundation

/// ActivityKit attributes for the "Mealgram — Today" Live Activity.
///
/// Static side is empty for now — the activity has no per-instance
/// identity beyond "today". The `ContentState` carries everything the
/// Lock Screen + Dynamic Island views need to render: calorie ring,
/// macro bars, water and a timestamp.
///
/// Lives in `Shared/` so both the iOS app (which calls `Activity.request`
/// + `Activity.update`) and the Widget Extension (which renders the
/// activity views) compile against the same type.
struct MealgramActivityAttributes: ActivityAttributes {
    public typealias ContentState = State

    /// Snapshot of today's calorie + macro + water progress. Updated by
    /// `LiveActivityService.update(state:)` on every `TodayState.refresh`,
    /// every water log and every meal save. All fields default-zeroed so
    /// a fresh activity at the start of the day renders a valid (empty)
    /// state without throwing.
    struct State: Codable, Hashable, Sendable {
        var kcalConsumed: Int = 0
        var kcalGoal: Int = 0
        var proteinConsumed: Int = 0
        var proteinGoal: Int = 0
        var carbsConsumed: Int = 0
        var carbsGoal: Int = 0
        var fatConsumed: Int = 0
        var fatGoal: Int = 0
        var waterMl: Int = 0
        var waterGoalMl: Int = 0
        var updatedAt = Date(timeIntervalSince1970: 0)

        var kcalRemaining: Int {
            max(0, kcalGoal - kcalConsumed)
        }

        var calorieProgress: Double {
            guard kcalGoal > 0 else { return 0 }
            return min(1.0, Double(kcalConsumed) / Double(kcalGoal))
        }

        var proteinProgress: Double {
            guard proteinGoal > 0 else { return 0 }
            return min(1.0, Double(proteinConsumed) / Double(proteinGoal))
        }

        var carbsProgress: Double {
            guard carbsGoal > 0 else { return 0 }
            return min(1.0, Double(carbsConsumed) / Double(carbsGoal))
        }

        var fatProgress: Double {
            guard fatGoal > 0 else { return 0 }
            return min(1.0, Double(fatConsumed) / Double(fatGoal))
        }

        var waterProgress: Double {
            guard waterGoalMl > 0 else { return 0 }
            return min(1.0, Double(waterMl) / Double(waterGoalMl))
        }

        static let preview = State(
            kcalConsumed: 1340,
            kcalGoal: 2100,
            proteinConsumed: 78,
            proteinGoal: 120,
            carbsConsumed: 160,
            carbsGoal: 240,
            fatConsumed: 45,
            fatGoal: 70,
            waterMl: 1400,
            waterGoalMl: 2500,
            updatedAt: Date()
        )
    }
}

/// Centralised deep-link URLs the Live Activity opens. Mirrors
/// `WatchMessageKey` — one place to keep strings so the app side
/// and the widget side never drift.
enum MealgramActivityDeepLink {
    static let scheme = "mealgram"
    static let addWaterHost = "add-water"

    /// Tapping the "+1 szklanka" button in the expanded Dynamic Island
    /// opens this URL. The iOS app routes it via `.onOpenURL` to the
    /// water-log path. ActivityKit forbids mutating user data directly
    /// from a Live Activity view, so the deep-link bounce is the path.
    ///
    /// Built via `URLComponents` (no force-unwrap, swiftlint-clean) and
    /// falls back to a sentinel `about:blank` only if URL construction
    /// somehow fails (impossible for static literals — defensive).
    static var addWater: URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = addWaterHost
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
