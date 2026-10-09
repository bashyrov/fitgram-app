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

    /// Who can read my posts. Friends always can; `.everyone` opens them to
    /// anyone who finds the profile.
    enum PostsVisibility: String, Codable, Sendable, CaseIterable {
        case friends
        case everyone = "public"
    }

    var postsVisibility: PostsVisibility = .friends

    static let `default` = PrivacySettings()

    init() {}

    /// Settings saved before a field existed must still decode.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = PrivacySettings()
        visibility = try container.decodeIfPresent(Visibility.self, forKey: .visibility) ?? defaults.visibility
        showStreak = try container.decodeIfPresent(Bool.self, forKey: .showStreak) ?? defaults.showStreak
        showLevel = try container.decodeIfPresent(Bool.self, forKey: .showLevel) ?? defaults.showLevel
        showAchievements =
            try container.decodeIfPresent(Bool.self, forKey: .showAchievements) ?? defaults.showAchievements
        showGoal = try container.decodeIfPresent(Bool.self, forKey: .showGoal) ?? defaults.showGoal
        showWeeklyStats = try container.decodeIfPresent(Bool.self, forKey: .showWeeklyStats) ?? defaults.showWeeklyStats
        showRecipes = try container.decodeIfPresent(Bool.self, forKey: .showRecipes) ?? defaults.showRecipes
        showWeightAndHeight =
            try container.decodeIfPresent(Bool.self, forKey: .showWeightAndHeight) ?? defaults.showWeightAndHeight
        showMealDetails = try container.decodeIfPresent(Bool.self, forKey: .showMealDetails) ?? defaults.showMealDetails
        postsVisibility =
            try container.decodeIfPresent(PostsVisibility.self, forKey: .postsVisibility) ?? defaults.postsVisibility
    }
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
    /// Fired after a user-initiated change so the backend copy follows.
    var onChange: (@MainActor (PrivacySettings) -> Void)?

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
        replace(copy)
    }

    /// `notify: false` is for adopting the server's copy without echoing it
    /// straight back.
    func replace(_ settings: PrivacySettings, notify: Bool = true) {
        current = settings
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: storageKey)
        }
        if notify { onChange?(settings) }
    }
}
