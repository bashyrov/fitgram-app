import Foundation

/// Per-account settings kept in `UserDefaults` (AI usage counters, privacy,
/// reminders, coach state, Quick DB picks, ...).
///
/// The app reads these keys directly, so only the signed-in account's values
/// may be "live". When another account signs in, the previous account's
/// values are packed into one stash entry and the new account's stash is
/// unpacked in their place. Device-wide settings (language, theme, accent,
/// app icon) are not listed and stay shared.
enum AccountDefaults {
    /// Account that owns the live values. Absent before the first sign-in
    /// after this was introduced: the live values then belong to whoever
    /// signs in first, matching how unowned meals are claimed.
    static let ownerKey = "accountDefaultsOwner"
    static let stashPrefix = "accountDefaultsStash."

    static let prefixes = [
        "usage.",
        "water.",
        "weight.",
        "privacy.",
        "coach.",
        "cultural.",
        "debug.",
        "whatsnew.",
        "olaChef.",
        "foodPicks.",
        "notifications.friend",
        "onboarding.demoScanUsed",
        "fitgram.health.",
        "fitgram.activityCalories.",
        "preferences.friend.",
        "preferences.morningReminder",
        "preferences.streakRisk",
        "preferences.eveningReminder",
        "preferences.goalWeight",
    ]

    static func isAccountKey(_ key: String) -> Bool {
        prefixes.contains { key.hasPrefix($0) }
    }

    static func owner(in defaults: UserDefaults = .standard) -> String? {
        defaults.string(forKey: ownerKey)
    }

    /// Makes `userID`'s values live. Returns true when another account's
    /// values were swapped out, so callers can reload what they cached.
    @discardableResult
    static func switchTo(_ userID: String, in defaults: UserDefaults = .standard) -> Bool {
        let current = owner(in: defaults)
        guard current != userID else { return false }
        defaults.set(userID, forKey: ownerKey)
        guard let current else { return false }

        let live = liveValues(in: defaults)
        if !current.isEmpty, !live.isEmpty {
            defaults.set(live, forKey: stashPrefix + current)
        }
        live.keys.forEach(defaults.removeObject(forKey:))
        if let stash = defaults.dictionary(forKey: stashPrefix + userID) {
            for (key, value) in stash { defaults.set(value, forKey: key) }
            defaults.removeObject(forKey: stashPrefix + userID)
        }
        return true
    }

    /// Drops everything stored for `userID`: its live values when it owns
    /// them, and its stash. Other accounts' stashes are untouched.
    static func forget(_ userID: String, in defaults: UserDefaults = .standard) {
        if owner(in: defaults) == userID {
            liveValues(in: defaults).keys.forEach(defaults.removeObject(forKey:))
            // "" = no live owner, but not a pre-scoping install either: the
            // next account must still get its stash back.
            defaults.set("", forKey: ownerKey)
        }
        defaults.removeObject(forKey: stashPrefix + userID)
    }

    private static func liveValues(in defaults: UserDefaults) -> [String: Any] {
        defaults.dictionaryRepresentation().filter { isAccountKey($0.key) }
    }
}
