import Foundation
import OSLog

struct SupabaseProfileProvisioner: Sendable {
    private let client: SupabaseRESTClient?

    init(client: SupabaseRESTClient? = SupabaseRESTClient()) {
        self.client = client
    }

    func ensureProfile(userID: String, displayName: String?) async {
        guard let client, UUID(uuidString: userID) != nil else { return }
        do {
            let username = Self.defaultUsername(for: userID)
            let profile = PublicProfileUpsert(
                userID: userID,
                username: username,
                displayName: displayName?.nilIfBlank ?? username,
                photoURL: nil
            )
            // Never overwrite an existing row: the username is locked once
            // chosen. Only the display name follows the auth provider.
            try await client.request(
                path: "public_profiles",
                method: .post,
                body: profile,
                prefer: "resolution=ignore-duplicates,return=minimal"
            )
            if let name = displayName?.nilIfBlank {
                try await client.request(
                    path: "public_profiles",
                    method: .patch,
                    query: [URLQueryItem(name: "user_id", value: "eq.\(userID)")],
                    body: DisplayNamePatch(displayName: name),
                    prefer: "return=minimal"
                )
            }
            let privacy = PrivacyUpsert(userID: userID)
            try await client.request(
                path: "profile_privacy",
                method: .post,
                body: privacy,
                prefer: "resolution=ignore-duplicates"
            )
        } catch {
            Logger.auth.error("Supabase profile provisioning failed: \(String(describing: error))")
        }
    }

    static func defaultUsername(for userID: String) -> String {
        let suffix = userID.replacingOccurrences(of: "-", with: "").prefix(10).lowercased()
        return "mg\(suffix)"
    }
}

private struct PublicProfileUpsert: Encodable {
    let userID: String
    let username: String
    let displayName: String
    let photoURL: String?
}

private struct DisplayNamePatch: Encodable {
    let displayName: String
}

private struct PrivacyUpsert: Encodable {
    let userID: String
    let visibility: String = "public"
    let showStreak: Bool = true
    let showAchievements: Bool = true
    let showGoal: Bool = false
    let showWeeklyStats: Bool = false
    let showRecipes: Bool = false
    let showWeightHeight: Bool = false
    let showMealDetails: Bool = false
}
