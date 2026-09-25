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
        var goalWeight: Bool
        /// Hour (0–23) the goal-weight reminder fires at. Defaults to 9.
        var goalWeightHour: Int
        /// Minute (0–59) the goal-weight reminder fires at. Defaults to 0.
        var goalWeightMinute: Int

        static let `default` = Preferences(
            morningGreeting: true,
            streakRisk: true,
            eveningSummary: true,
            goalWeight: true,
            goalWeightHour: 9,
            goalWeightMinute: 0
        )

        static let allOff = Preferences(
            morningGreeting: false,
            streakRisk: false,
            eveningSummary: false,
            goalWeight: false,
            goalWeightHour: 9,
            goalWeightMinute: 0
        )
    }

    /// Snapshot of what the planner needs to decide each reminder.
    struct Context: Sendable {
        var preferences: Preferences
        var hasLoggedToday: Bool
        var calendar: Calendar
        var now: Date
        /// True when the user has an active "lose" / "gain" goal *and*
        /// the Premium entitlement that unlocks goal tracking. Drives the
        /// goal-weight reminder gate.
        var hasActiveGoal: Bool = false
        /// True when the user has already entered a weigh-in for today
        /// (any source). Silences the goal-weight reminder.
        var hasLoggedGoalWeightToday: Bool = false
        var currentStreakLength: Int = 0
        var freezesAvailable: Int = 0
        var hasProtectedStreakToday: Bool = false
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
        let shouldSendStreakRisk =
            context.preferences.streakRisk && !context.hasLoggedToday && !context.hasProtectedStreakToday
        if shouldSendStreakRisk {
            plan.streakRisk = DateComponents(hour: 20, minute: 30)
            plan.streakRiskSuggestsFreeze = context.currentStreakLength > 0 && context.freezesAvailable > 0
        }

        // Evening wrap-up — independent of logging activity; always a
        // gentle "look at your day" nudge.
        if context.preferences.eveningSummary {
            plan.eveningSummary = DateComponents(hour: 21, minute: 0)
        }

        // Goal weight reminder — gated on having an active goal + Premium
        // (caller folds both into `hasActiveGoal`). Silenced once the
        // user has already logged a weigh-in today.
        let shouldSendGoalWeight =
            context.preferences.goalWeight && context.hasActiveGoal && !context.hasLoggedGoalWeightToday
        if shouldSendGoalWeight {
            plan.goalWeight = DateComponents(
                hour: context.preferences.goalWeightHour,
                minute: context.preferences.goalWeightMinute
            )
        }

        return plan
    }
}
