import Foundation

/// Rich projection of a friend's data — the union of every field the
/// owner might choose to share. Fields are Optional so the produced
/// snapshot literally drops anything the owner's PrivacySettings hides.
/// Building this respects the owner's settings; the UI just renders
/// whatever fields are non-nil.
struct FriendProfileSnapshot: Equatable, Sendable, Identifiable {
    let id: String  // == userRemoteID
    let displayName: String
    let username: String?
    let avatarURL: URL?
    let bio: String?
    let memberSinceDate: Date?

    // Shared per privacy toggles.
    let currentStreak: Int?
    let level: ProfileLevel?
    let goalLabel: String?
    let achievements: [Achievement]?
    let weeklyStats: WeeklyStats?
    let topRecipes: [PublicRecipeReference]?
    let recentEvents: [FeedEvent]?
    let weightKg: Double?
    let heightCm: Int?

    var hasAnyShared: Bool {
        currentStreak != nil
            || level != nil
            || goalLabel != nil
            || (achievements?.isEmpty == false)
            || weeklyStats != nil
            || (topRecipes?.isEmpty == false)
            || (recentEvents?.isEmpty == false)
            || weightKg != nil
            || heightCm != nil
    }
}

struct ProfileLevel: Equatable, Sendable {
    let number: Int
    let label: String  // "Pro", "Explorer", etc.
}

struct WeeklyStats: Equatable, Sendable {
    let averageDailyKcal: Int
    let totalScans: Int
    let daysHitGoal: Int
    let topFoods: [String]
}

struct PublicRecipeReference: Equatable, Sendable, Identifiable {
    let id: UUID
    let name: String
    let kcalPerServing: Int?
    let cookCount: Int
}

/// Per-spec only positive reactions on a friend's event.
enum PositiveReactionIntent: String, Sendable, CaseIterable {
    case encourage = "encourage"
    case celebrate = "celebrate"
    case congratulate = "congratulate"

    var label: String {
        switch self {
        case .encourage: return "Zachęć"
        case .celebrate: return "Pogratuluj"
        case .congratulate: return "Brawo"
        }
    }

    var symbol: String {
        switch self {
        case .encourage: return "hand.thumbsup.fill"
        case .celebrate: return "party.popper.fill"
        case .congratulate: return "rosette"
        }
    }
}
