import Foundation

/// Pure-function planner: given the user's preferences + last activity,
/// returns the `NotificationPlan` the service should commit. No system
/// calls live here — keeps the rules trivially testable.
struct NotificationPlanner {
    /// What the user toggled in Profile. Defaults assume the
    /// soft-permission ask succeeded during onboarding.
    struct Preferences: Equatable, Sendable {
        var morningGreeting: Bool
        var streakRisk: Bool
        var eveningSummary: Bool

        static let `default` = Preferences(
            morningGreeting: true,
            streakRisk: true,
            eveningSummary: true
        )

        static let allOff = Preferences(
            morningGreeting: false,
            streakRisk: false,
            eveningSummary: false
        )
    }

    /// Snapshot of what the planner needs to decide each reminder.
    struct Context: Sendable {
        var preferences: Preferences
        var hasLoggedToday: Bool
        var calendar: Calendar
        var now: Date
    }

    static func plan(_ context: Context) -> NotificationPlan {
        var plan = NotificationPlan.empty

        // Morning greeting — silenced once the user has already logged a
        // meal today (avoids redundant nag).
        if context.preferences.morningGreeting, !context.hasLoggedToday {
            plan.morningGreeting = DateComponents(hour: 8, minute: 0)
        }

        // Streak-at-risk — only when the user genuinely hasn't logged
        // today. Repeats daily; the next reschedule on app foreground +
        // meal save will clear it as soon as they log.
        if context.preferences.streakRisk, !context.hasLoggedToday {
            plan.streakRisk = DateComponents(hour: 20, minute: 30)
        }

        // Evening wrap-up — independent of logging activity; always a
        // gentle "look at your day" nudge.
        if context.preferences.eveningSummary {
            plan.eveningSummary = DateComponents(hour: 21, minute: 0)
        }

        return plan
    }
}
