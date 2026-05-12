import Foundation

/// Lightweight value types for the social graph. Live independently of
/// SwiftData on purpose — the social graph is server-authoritative
/// (Supabase) once the backend is wired; we cache snapshots locally but
/// never use SwiftData as the source of truth.

/// Public profile snapshot — what one friend sees about another.
struct PublicProfile: Equatable, Sendable, Identifiable {
    let id: String  // == userRemoteID
    let displayName: String
    let avatarURL: URL?
    let sharesStreak: Bool
    let sharesAchievements: Bool
    let currentStreak: Int?
    let achievementCount: Int?
}

struct FriendRequest: Equatable, Sendable, Identifiable {
    enum Status: String, Codable, Sendable {
        case pending
        case accepted
        case rejected
        case cancelled
    }

    let id: UUID
    let fromUserID: String
    let toUserID: String
    var status: Status
    let createdAt: Date
}

/// Event kinds the feed renders. Stable raw strings so the Supabase
/// `feed_events.kind` column matches without translation.
enum FeedEventKind: String, Codable, Sendable, CaseIterable {
    case streakMilestone = "streak.milestone"
    case achievementEarned = "achievement.earned"
    case recipeCooked = "recipe.cooked"
    case challengeWon = "challenge.won"
    case joined = "user.joined"
}

struct FeedEvent: Equatable, Sendable, Identifiable {
    let id: UUID
    let actorID: String  // who triggered it
    let actorDisplayName: String
    let actorAvatarURL: URL?
    let kind: FeedEventKind
    let payload: String  // free-form human-readable summary
    let createdAt: Date
    var reactions: [ReactionKind: Int]  // counts, never negative
    var myReaction: ReactionKind?  // current user's reaction, if any
}

/// Only positive reactions — the master prompt is explicit about avoiding
/// any path that could surface negativity (no comments, no thumbs-down).
enum ReactionKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case heart
    case clap
    case flame
    case sparkles

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .clap: return "👏"
        case .flame: return "🔥"
        case .sparkles: return "✨"
        }
    }

    var label: String {
        switch self {
        case .heart: return "Serce"
        case .clap: return "Brawo"
        case .flame: return "Ogień"
        case .sparkles: return "Iskry"
        }
    }
}

enum FriendError: Error, Equatable {
    case notConfigured
    case notFound(query: String)
    case alreadyFriends
    case alreadyRequested
    case network(String)
}
