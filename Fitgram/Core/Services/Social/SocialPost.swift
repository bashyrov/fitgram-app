import Foundation

/// Macros attached to a post: either a whole logged day or one meal, frozen
/// at publish time so later edits to the diary don't rewrite old posts.
struct PostMacroSnapshot: Codable, Equatable, Sendable {
    enum Scope: String, Codable, Sendable {
        case day
        case meal
    }

    let scope: Scope
    /// Meal name ("Obiad") or nil for a whole day.
    let label: String?
    /// When it was eaten: the meal time, or any moment of the day for `.day`.
    let consumedAt: Date
    let kcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    /// Daily goal at the time of posting, so the card can show progress.
    let goalKcal: Int?
    /// Up to four food names, biggest first.
    let items: [String]
    let mealCount: Int
}

/// A logged workout attached to a post, frozen at publish time.
struct PostActivitySnapshot: Codable, Equatable, Sendable {
    let name: String
    let symbol: String
    let startedAt: Date
    let durationMinutes: Int
    let kcalBurned: Int
    let distanceMeters: Double?
    let steps: Int?
    let averageHeartRate: Int?
}

struct SocialPost: Identifiable, Equatable, Sendable {
    let id: UUID
    let authorID: String
    let authorName: String
    let authorUsername: String?
    let authorIsPremium: Bool
    let title: String
    let body: String
    let photoURL: URL?
    let macros: PostMacroSnapshot?
    var activity: PostActivitySnapshot?
    let createdAt: Date
    var likeCount: Int
    var isLikedByMe: Bool
}

/// What the composer hands to `PostService.create`.
struct PostDraft: Sendable {
    var title: String
    var body: String
    var photoJPEG: Data?
    /// Macros *or* an activity — never both.
    var macros: PostMacroSnapshot?
    var activity: PostActivitySnapshot?
}

/// Posts of one author as seen by a viewer. `isHidden` distinguishes
/// "no posts yet" from "the author's privacy settings hide them".
struct AuthorPosts: Equatable, Sendable {
    let posts: [SocialPost]
    let isHidden: Bool
}

enum PostLimits {
    /// Premium users may publish at most this many posts per calendar day.
    static let dailyMax = 7
    static let titleMax = 60
    static let titleMin = 3
    static let bodyMax = 500
}

enum PostError: Error, Equatable {
    case premiumRequired
    case dailyLimitReached
    case contentRejected
    /// Macros and an activity were both attached.
    case oneAttachmentOnly
    case photoUpload(String)
    case notFound
    case network(String)
}
