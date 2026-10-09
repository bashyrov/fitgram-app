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
    /// Without the "@". Nil for profiles that only exist locally.
    var username: String?
    var isPremium: Bool = false

    /// "@kasia.nowak", or nil.
    var handle: String? { username.map { "@\($0)" } }

    /// What other people see: the username; the real name stays private to
    /// its owner. Falls back to the name for profiles without a username.
    var publicName: String { username?.nilIfBlank ?? displayName }
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
    /// The other person — the sender for incoming requests, the receiver
    /// for outgoing ones. Filled in by the service when it can read them.
    var counterpart: PublicProfile?
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

struct FriendReactionNotification: Equatable, Sendable, Identifiable {
    let id: UUID
    let fromUserID: String
    let fromDisplayName: String
    let kind: ReactionKind
    let createdAt: Date
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
        case .heart: return L("Serce")
        case .clap: return L("Brawo")
        case .flame: return L("Ogień")
        case .sparkles: return L("Iskry")
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
