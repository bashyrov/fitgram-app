import Foundation
import Observation

/// What another user is allowed to see when they open my profile. Stored
/// locally (UserDefaults via PrivacyStore) and mirrored to Supabase
/// once the backend is wired. Default = `.private` with every toggle
/// off — privacy-first per spec.
struct PrivacySettings: Codable, Equatable, Sendable {
    enum Visibility: String, Codable, Sendable, CaseIterable {
        case privateOnly = "private"
        case friendsOnly = "friends"
        case publicLink = "public"
    }

    var visibility: Visibility = .privateOnly
    var showStreak: Bool = false
    var showLevel: Bool = false
    var showAchievements: Bool = false
    var showGoal: Bool = false
    var showWeeklyStats: Bool = false
    var showRecipes: Bool = false
    /// OFF by default per spec — sensitive enough that we never silently
    /// share these even when the visibility is `friends`.
    var showWeightAndHeight: Bool = false
    var showMealDetails: Bool = false

    static let `default` = PrivacySettings()
}

/// Observable wrapper around the on-device privacy preferences. UI binds
/// to this directly; the Supabase sync layer pulls from `current` on
/// every change.
@MainActor
@Observable
final class PrivacyStore {
    private let defaults: UserDefaults
    private let storageKey: String

    private(set) var current: PrivacySettings

    init(defaults: UserDefaults = .standard, storageKey: String = "privacy.settings") {
        self.defaults = defaults
        self.storageKey = storageKey
        if let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(PrivacySettings.self, from: data)
        {
            self.current = decoded
        } else {
            self.current = .default
        }
    }

    func update(_ block: (inout PrivacySettings) -> Void) {
        var copy = current
        block(&copy)
        current = copy
        if let data = try? JSONEncoder().encode(copy) {
            defaults.set(data, forKey: storageKey)
        }
    }

    func replace(_ settings: PrivacySettings) {
        current = settings
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
