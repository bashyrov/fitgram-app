import Foundation

/// Thin UserDefaults wrapper so the rest of the app reads/writes through
/// stable keys and a single value type. The keys match the `@AppStorage`
/// entries in `PreferencesView` — changing them invalidates existing
/// installs, so don't.
struct NotificationPreferencesStore {
    enum Key {
        static let morning = "preferences.morningReminderEnabled"
        static let streakRisk = "preferences.streakRiskEnabled"
        static let evening = "preferences.eveningReminderEnabled"
        static let goalWeight = "preferences.goalWeightReminderEnabled"
        static let goalWeightHour = "preferences.goalWeightReminderHour"
        static let goalWeightMinute = "preferences.goalWeightReminderMinute"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationPlanner.Preferences {
        NotificationPlanner.Preferences(
            morningGreeting: bool(forKey: Key.morning, fallback: true),
            streakRisk: bool(forKey: Key.streakRisk, fallback: true),
            eveningSummary: bool(forKey: Key.evening, fallback: true),
            goalWeight: bool(forKey: Key.goalWeight, fallback: true),
            goalWeightHour: int(forKey: Key.goalWeightHour, fallback: 9, min: 0, max: 23),
            goalWeightMinute: int(forKey: Key.goalWeightMinute, fallback: 0, min: 0, max: 59)
        )
    }

    func save(_ preferences: NotificationPlanner.Preferences) {
        defaults.set(preferences.morningGreeting, forKey: Key.morning)
        defaults.set(preferences.streakRisk, forKey: Key.streakRisk)
        defaults.set(preferences.eveningSummary, forKey: Key.evening)
        defaults.set(preferences.goalWeight, forKey: Key.goalWeight)
        defaults.set(preferences.goalWeightHour, forKey: Key.goalWeightHour)
        defaults.set(preferences.goalWeightMinute, forKey: Key.goalWeightMinute)
    }

    /// Unseeded keys return `true` so a fresh install behaves like the
    /// user opted in during onboarding's soft ask.
    private func bool(forKey key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.bool(forKey: key)
    }

    private func int(forKey key: String, fallback: Int, min: Int, max: Int) -> Int {
        guard defaults.object(forKey: key) != nil else { return fallback }
        let value = defaults.integer(forKey: key)
        return Swift.min(Swift.max(value, min), max)
    }
}
