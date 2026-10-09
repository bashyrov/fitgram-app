import Foundation
import OSLog

/// The user's own social identity on the backend: the one-time username,
/// the Premium flag shown next to it, and the privacy settings that decide
/// who sees the profile and posts.
@MainActor
protocol SocialProfileServing: Sendable {
    func isUsernameAvailable(_ username: String) async throws -> Bool
    /// Throws `UsernameClaimError.taken` / `.locked`.
    func claimUsername(_ username: String, displayName: String?, userID: String) async throws
    /// The chosen username, or nil while only a placeholder exists.
    func chosenUsername(userID: String) async throws -> String?
    /// Mirrors the Premium mark and the current display name.
    func syncProfile(isPremium: Bool, displayName: String?, userID: String) async
    func syncPrivacy(_ settings: PrivacySettings, userID: String) async
    func fetchPrivacy(userID: String) async -> PrivacySettings?
}

enum UsernameClaimError: Error, Equatable {
    case invalid
    case taken
    /// A different username was already chosen; it can't be changed.
    case locked
    case network
}

@MainActor
enum SocialProfileServiceFactory {
    static func make() -> any SocialProfileServing {
        SupabaseSocialProfileService() ?? InMemorySocialProfileService.shared
    }
}

@MainActor
final class SupabaseSocialProfileService: SocialProfileServing {
    private let client: SupabaseRESTClient

    init?(client: SupabaseRESTClient? = SupabaseRESTClient()) {
        guard let client else { return nil }
        self.client = client
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        try await client.request(
            path: "rpc/username_available",
            method: .post,
            body: UsernameArgs(candidate: UsernamePolicy.normalize(username))
        )
    }

    func claimUsername(_ username: String, displayName: String?, userID: String) async throws {
        let name = UsernamePolicy.normalize(username)
        guard UsernamePolicy.isValid(name) else { throw UsernameClaimError.invalid }
        do {
            try await client.request(
                path: "public_profiles",
                method: .post,
                query: [URLQueryItem(name: "on_conflict", value: "user_id")],
                body: UsernameClaim(userID: userID, username: name, displayName: displayName?.nilIfBlank ?? name),
                prefer: "resolution=merge-duplicates,return=minimal"
            )
        } catch let SupabaseRESTClient.SupabaseError.http(_, body) {
            if body.contains("username_locked") { throw UsernameClaimError.locked }
            if body.contains("duplicate key") || body.contains("23505") { throw UsernameClaimError.taken }
            Logger.auth.error("Username claim failed: \(body, privacy: .public)")
            throw UsernameClaimError.network
        } catch {
            throw UsernameClaimError.network
        }
    }

    func chosenUsername(userID: String) async throws -> String? {
        let rows: [UsernameRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: "username,username_set"),
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let row = rows.first, row.usernameSet == true || !UsernamePolicy.isPlaceholder(row.username) else {
            return nil
        }
        return row.username
    }

    func syncProfile(isPremium: Bool, displayName: String?, userID: String) async {
        do {
            try await client.request(
                path: "public_profiles",
                method: .patch,
                query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
                body: ProfilePatch(isPremium: isPremium, displayName: displayName?.nilIfBlank),
                prefer: "return=minimal"
            )
        } catch {
            Logger.auth.error("Premium flag sync failed: \(String(describing: error))")
        }
    }

    func syncPrivacy(_ settings: PrivacySettings, userID: String) async {
        do {
            try await client.request(
                path: "profile_privacy",
                method: .post,
                query: [URLQueryItem(name: "on_conflict", value: "user_id")],
                body: PrivacyRow(settings: settings, userID: userID),
                prefer: "resolution=merge-duplicates,return=minimal"
            )
        } catch {
            Logger.auth.error("Privacy sync failed: \(String(describing: error))")
        }
    }

    func fetchPrivacy(userID: String) async -> PrivacySettings? {
        let rows: [PrivacyRow]? = try? await client.request(
            path: "profile_privacy",
            query: [
                URLQueryItem(name: "select", value: PrivacyRow.selectColumns),
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return rows?.first?.settings
    }
}

/// Used when Supabase isn't configured (local builds, tests).
@MainActor
final class InMemorySocialProfileService: SocialProfileServing {
    static let shared = InMemorySocialProfileService()

    private var claimed: [String: String] = [:]  // userID → username
    private var premium: [String: Bool] = [:]
    private var privacy: [String: PrivacySettings] = [:]
    /// Usernames of the demo friends — taken from the start.
    private let seededTaken: Set<String> = [
        "fitgram_test", "marta_fit", "ania.fit", "kasia_zdrowo", "michal", "ola_k", "nina", "piotr.k", "zosia.w",
    ]

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let name = UsernamePolicy.normalize(username)
        return !seededTaken.contains(name) && !claimed.values.contains(name)
    }

    func claimUsername(_ username: String, displayName: String?, userID: String) async throws {
        let name = UsernamePolicy.normalize(username)
        guard UsernamePolicy.isValid(name) else { throw UsernameClaimError.invalid }
        if let existing = claimed[userID] {
            if existing == name { return }
            throw UsernameClaimError.locked
        }
        guard try await isUsernameAvailable(name) else { throw UsernameClaimError.taken }
        claimed[userID] = name
    }

    func chosenUsername(userID: String) async throws -> String? { claimed[userID] }

    func syncProfile(isPremium: Bool, displayName: String?, userID: String) async { premium[userID] = isPremium }

    func syncPrivacy(_ settings: PrivacySettings, userID: String) async { privacy[userID] = settings }

    func fetchPrivacy(userID: String) async -> PrivacySettings? { privacy[userID] }

    func isPremium(_ userID: String) -> Bool { premium[userID] ?? false }
}

// MARK: - Rows

private struct UsernameArgs: Encodable {
    let candidate: String
}

private struct UsernameClaim: Encodable {
    let userID: String
    let username: String
    let displayName: String
}

private struct UsernameRow: Decodable, Sendable {
    let username: String
    let usernameSet: Bool?
}

private struct ProfilePatch: Encodable {
    let isPremium: Bool
    let displayName: String?
}

struct PrivacyRow: Codable, Sendable {
    static let selectColumns =
        "user_id,visibility,show_streak,show_level,show_achievements,show_goal,show_weekly_stats,show_recipes,"
        + "show_weight_height,show_meal_details,posts_visibility"

    let userID: String
    let visibility: String
    let showStreak: Bool
    let showLevel: Bool
    let showAchievements: Bool
    let showGoal: Bool
    let showWeeklyStats: Bool
    let showRecipes: Bool
    let showWeightHeight: Bool
    let showMealDetails: Bool
    let postsVisibility: String?

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case visibility, showStreak, showLevel, showAchievements, showGoal, showWeeklyStats, showRecipes
        case showWeightHeight, showMealDetails, postsVisibility
    }

    init(settings: PrivacySettings, userID: String) {
        self.userID = userID
        self.visibility = settings.visibility.rawValue
        self.showStreak = settings.showStreak
        self.showLevel = settings.showLevel
        self.showAchievements = settings.showAchievements
        self.showGoal = settings.showGoal
        self.showWeeklyStats = settings.showWeeklyStats
        self.showRecipes = settings.showRecipes
        self.showWeightHeight = settings.showWeightAndHeight
        self.showMealDetails = settings.showMealDetails
        self.postsVisibility = settings.postsVisibility.rawValue
    }

    var settings: PrivacySettings {
        var result = PrivacySettings()
        result.visibility = PrivacySettings.Visibility(rawValue: visibility) ?? .privateOnly
        result.showStreak = showStreak
        result.showLevel = showLevel
        result.showAchievements = showAchievements
        result.showGoal = showGoal
        result.showWeeklyStats = showWeeklyStats
        result.showRecipes = showRecipes
        result.showWeightAndHeight = showWeightHeight
        result.showMealDetails = showMealDetails
        result.postsVisibility = postsVisibility.flatMap(PrivacySettings.PostsVisibility.init(rawValue:)) ?? .friends
        return result
    }
}
