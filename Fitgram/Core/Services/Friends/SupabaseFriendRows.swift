import Foundation

// PostgREST row shapes used by SupabaseFriendService.
//
// The client decodes with `.convertFromSnakeCase`, which turns `user_id`
// into `userId` — not `userID`. Rows with acronym properties therefore map
// their keys explicitly; without that every profile / feed decode failed
// and the friends list was always empty.

struct PublicProfileRow: Decodable {
    let userID: String
    let username: String
    let displayName: String?
    let photoURL: String?
    let bio: String?
    let createdAt: String?

    private enum CodingKeys: String, CodingKey {
        case userID = "userId"
        case username
        case displayName
        case photoURL = "photoUrl"
        case bio
        case createdAt
    }

    var toPublicProfile: PublicProfile {
        PublicProfile(
            id: userID,
            displayName: displayName?.nilIfBlank ?? "@\(username)",
            avatarURL: photoURL.flatMap(URL.init(string:)),
            sharesStreak: true,
            sharesAchievements: true,
            currentStreak: nil,
            achievementCount: nil
        )
    }
}

struct FriendshipRow: Decodable {
    let id: UUID
    let userA: String
    let userB: String
    let status: String
    let requestedBy: String
    let requestedAt: String

    var toRequest: FriendRequest {
        FriendRequest(
            id: id,
            fromUserID: requestedBy,
            toUserID: otherUserID(for: requestedBy),
            status: FriendRequest.Status(rawValue: status) ?? .pending,
            createdAt: requestedAt.supabaseDate
        )
    }

    func otherUserID(for userID: String) -> String {
        userA == userID ? userB : userA
    }
}

struct ActivityEventRow: Decodable {
    let id: UUID
    let userID: String
    let eventType: String
    let eventData: EventData
    let createdAt: String

    var createdAtDate: Date { createdAt.supabaseDate }

    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case eventType
        case eventData
        case createdAt
    }
}

struct EventData: Decodable {
    let title: String?
    let summary: String?

    init(from decoder: any Decoder) throws {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        self.title = try? container?.decodeIfPresent(String.self, forKey: .title)
        self.summary = try? container?.decodeIfPresent(String.self, forKey: .summary)
    }

    private enum CodingKeys: String, CodingKey {
        case title
        case summary
    }
}

struct ReactionRow: Decodable {
    let fromUser: String
    let eventID: UUID?
    let reactionType: String

    var kind: ReactionKind? { ReactionKind(rawValue: reactionType) }

    private enum CodingKeys: String, CodingKey {
        case fromUser
        case eventID = "eventId"
        case reactionType
    }
}

struct IncomingReactionRow: Decodable {
    let id: UUID
    let fromUser: String
    let toUser: String
    let reactionType: String
    let createdAt: String

    var notificationKind: ReactionKind? {
        if let kind = ReactionKind(rawValue: reactionType) { return kind }
        switch PositiveReactionIntent(rawValue: reactionType) {
        case .encourage: return .heart
        case .celebrate: return .sparkles
        case .congratulate: return .clap
        case .none: return nil
        }
    }
}

struct BlockRow: Decodable {
    let blocked: String
}

struct FriendshipInsert: Encodable {
    let userA: String
    let userB: String
    let status: String
    let requestedBy: String
}

struct FriendshipUpdate: Encodable {
    let status: String
    let acceptedAt: Date?
}

struct ReactionInsert: Encodable {
    let fromUser: String
    let toUser: String
    let eventID: UUID?
    let reactionType: String
}

struct BlockInsert: Encodable {
    let blocker: String
    let blocked: String
}

struct ReportInsert: Encodable {
    let reporter: String
    let reported: String
    let reason: String
}

extension String {
    /// Trimmed value, or nil when only whitespace is left.
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var supabaseDate: Date {
        SupabaseDateParser.parse(self) ?? Date()
    }
}

private enum SupabaseDateParser {
    static func parse(_ raw: String) -> Date? {
        if let date = fractional.date(from: raw) { return date }
        return plain.date(from: raw)
    }

    nonisolated(unsafe) private static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()
}
