import Foundation

/// Thin UserDefaults wrapper so the rest of the app reads/writes through
/// stable keys and a single value type. The keys match the `@AppStorage`
/// entries in `PreferencesView` — changing them invalidates existing
/// installs, so don't.
struct NotificationPreferencesStore {
    private enum Key {
        static let morning = "preferences.morningReminderEnabled"
        static let streakRisk = "preferences.streakRiskEnabled"
        static let evening = "preferences.eveningReminderEnabled"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> NotificationPlanner.Preferences {
        NotificationPlanner.Preferences(
            morningGreeting: bool(forKey: Key.morning, fallback: true),
            streakRisk: bool(forKey: Key.streakRisk, fallback: true),
            eveningSummary: bool(forKey: Key.evening, fallback: true)
        )
    }

    func save(_ preferences: NotificationPlanner.Preferences) {
        defaults.set(preferences.morningGreeting, forKey: Key.morning)
        defaults.set(preferences.streakRisk, forKey: Key.streakRisk)
        defaults.set(preferences.eveningSummary, forKey: Key.evening)
    }

    /// Unseeded keys return `true` so a fresh install behaves like the
    /// user opted in during onboarding's soft ask.
    private func bool(forKey key: String, fallback: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return fallback }
        return defaults.bool(forKey: key)
    }
}
