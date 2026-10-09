import Foundation

@MainActor
final class SupabaseFriendService: FriendService {
    private let client: SupabaseRESTClient

    init?(client: SupabaseRESTClient? = SupabaseRESTClient()) {
        guard let client else { return nil }
        self.client = client
    }

    func friends(of userID: String) async throws -> [PublicProfile] {
        let rows = try await friendshipRows(
            userID: userID,
            extra: [URLQueryItem(name: "status", value: "eq.accepted")]
        )
        let ids = rows.map { $0.otherUserID(for: userID) }
        return try await profiles(ids: ids).sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    func pendingIncoming(for userID: String) async throws -> [FriendRequest] {
        let rows = try await friendshipRows(
            userID: userID,
            extra: [
                URLQueryItem(name: "status", value: "eq.pending"),
                URLQueryItem(name: "requested_by", value: "neq.\(userID)"),
            ]
        )
        return try await withCounterparts(rows.map(\.toRequest), viewer: userID)
    }

    func pendingOutgoing(for userID: String) async throws -> [FriendRequest] {
        let rows = try await friendshipRows(
            userID: userID,
            extra: [
                URLQueryItem(name: "status", value: "eq.pending"),
                URLQueryItem(name: "requested_by", value: "eq.\(userID)"),
            ]
        )
        return try await withCounterparts(rows.map(\.toRequest), viewer: userID)
    }

    func search(query: String, excluding userID: String) async throws -> [PublicProfile] {
        let cleaned = query.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "@", with: "")
            .filter { !",()*%".contains($0) }
        guard cleaned.count >= 2 else { return [] }
        let pattern = "*\(cleaned)*"
        let rows: [PublicProfileRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: PublicProfileRow.selectColumns),
                URLQueryItem(name: "user_id", value: "neq.\(userID)"),
                URLQueryItem(name: "or", value: "(username.ilike.\(pattern),display_name.ilike.\(pattern))"),
                URLQueryItem(name: "limit", value: "12"),
            ]
        )
        return rows.map(\.toPublicProfile)
    }

    func profile(forCode code: String) async throws -> PublicProfile {
        let resolved = Self.extractCode(code)
        let isUserID = UUID(uuidString: resolved) != nil
        let filterName = isUserID ? "user_id" : "username"
        let rows: [PublicProfileRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: PublicProfileRow.selectColumns),
                URLQueryItem(name: filterName, value: "eq.\(isUserID ? resolved : UsernamePolicy.normalize(resolved))"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let row = rows.first else { throw FriendError.notFound(query: code) }
        return row.toPublicProfile
    }

    func sendRequest(from: String, to: String) async throws -> FriendRequest {
        if let existing = try await pairRow(userID: from, friendID: to) {
            if existing.status == "accepted" { throw FriendError.alreadyFriends }
            if existing.status == "pending" { return existing.toRequest }
        }
        let pair = Self.orderedPair(from, to)
        let payload = FriendshipInsert(
            userA: pair.0,
            userB: pair.1,
            status: "pending",
            requestedBy: from
        )
        let rows: [FriendshipRow] = try await client.request(
            path: "friendships",
            method: .post,
            body: payload,
            prefer: "return=representation"
        )
        guard let row = rows.first else { throw FriendError.network("Empty friendship response") }
        return row.toRequest
    }

    func accept(request: FriendRequest, as userID: String) async throws {
        try await client.request(
            path: "friendships",
            method: .patch,
            query: [URLQueryItem(name: "id", value: "eq.\(request.id.uuidString)")],
            body: FriendshipUpdate(status: "accepted", acceptedAt: Date()),
            prefer: "return=minimal"
        )
    }

    /// `friendships.status` only allows pending / accepted / blocked, so a
    /// declined request is removed instead of being marked "rejected".
    func reject(request: FriendRequest, as userID: String) async throws {
        try await client.request(
            path: "friendships",
            method: .delete,
            query: [URLQueryItem(name: "id", value: "eq.\(request.id.uuidString)")]
        )
    }

    func unfriend(_ friendID: String, as userID: String) async throws {
        let pair = Self.orderedPair(userID, friendID)
        try await client.request(
            path: "friendships",
            method: .delete,
            query: [
                URLQueryItem(name: "user_a", value: "eq.\(pair.0)"),
                URLQueryItem(name: "user_b", value: "eq.\(pair.1)"),
            ]
        )
    }

    func recentFeed(for userID: String, limit: Int) async throws -> [FeedEvent] {
        let friendIDs = try await friends(of: userID).map(\.id)
        guard !friendIDs.isEmpty else { return [] }
        let rows: [ActivityEventRow] = try await client.request(
            path: "activity_events",
            query: [
                URLQueryItem(name: "select", value: "id,user_id,event_type,event_data,created_at"),
                URLQueryItem(name: "user_id", value: "in.(\(friendIDs.joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        )
        return try await hydrateEvents(rows, viewerID: userID)
    }

    func react(to event: FeedEvent, as userID: String, kind: ReactionKind?) async throws -> FeedEvent {
        try await client.request(
            path: "reactions",
            method: .delete,
            query: [
                URLQueryItem(name: "event_id", value: "eq.\(event.id.uuidString)"),
                URLQueryItem(name: "from_user", value: "eq.\(userID)"),
                URLQueryItem(name: "reaction_type", value: "in.(heart,clap,flame,sparkles)"),
            ]
        )
        if let kind {
            try await client.request(
                path: "reactions",
                method: .post,
                body: ReactionInsert(
                    fromUser: userID,
                    toUser: event.actorID,
                    eventID: event.id,
                    reactionType: kind.rawValue
                ),
                prefer: "return=minimal"
            )
        }
        let rows: [ActivityEventRow] = try await client.request(
            path: "activity_events",
            query: [
                URLQueryItem(name: "select", value: "id,user_id,event_type,event_data,created_at"),
                URLQueryItem(name: "id", value: "eq.\(event.id.uuidString)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return try await hydrateEvents(rows, viewerID: userID).first ?? event
    }

    func snapshot(forUserID userID: String, viewer: String) async throws -> FriendProfileSnapshot {
        let profileRows: [PublicProfileRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: PublicProfileRow.selectColumns),
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        guard let profileRow = profileRows.first else { throw FriendError.notFound(query: userID) }
        let profile = profileRow.toPublicProfile
        let canView: Bool = try await client.request(
            path: "rpc/can_view_profile",
            method: .post,
            body: ViewerOwnerArgs(viewer: viewer, owner: userID)
        )
        guard canView else {
            return FriendProfileSnapshot(
                id: profile.id, displayName: profile.displayName, username: profile.handle,
                avatarURL: profile.avatarURL, bio: nil, memberSinceDate: nil, currentStreak: nil, level: nil,
                goalLabel: nil, achievements: nil, weeklyStats: nil, topRecipes: nil, recentEvents: nil,
                weightKg: nil, heightCm: nil, isPremium: profile.isPremium, isRestricted: true
            )
        }
        let eventRows: [ActivityEventRow] = try await client.request(
            path: "activity_events",
            query: [
                URLQueryItem(name: "select", value: "id,user_id,event_type,event_data,created_at"),
                URLQueryItem(name: "user_id", value: "eq.\(userID)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "12"),
            ]
        )
        return FriendProfileSnapshot(
            id: profile.id,
            displayName: profile.displayName,
            username: profileRow.username.isEmpty ? nil : "@\(profileRow.username)",
            avatarURL: profile.avatarURL,
            bio: profileRow.bio?.nilIfBlank,
            memberSinceDate: profileRow.createdAt?.supabaseDate,
            currentStreak: profile.currentStreak,
            level: nil,
            goalLabel: nil,
            achievements: nil,
            weeklyStats: nil,
            topRecipes: nil,
            recentEvents: try await hydrateEvents(eventRows, viewerID: viewer),
            weightKg: nil,
            heightCm: nil,
            isPremium: profile.isPremium
        )
    }

    func sendPositiveReaction(to userID: String, from viewer: String, intent: PositiveReactionIntent) async throws {
        try await client.request(
            path: "reactions",
            method: .post,
            body: ReactionInsert(
                fromUser: viewer,
                toUser: userID,
                eventID: nil,
                reactionType: intent.rawValue
            ),
            prefer: "return=minimal"
        )
    }

    func incomingReactions(for userID: String, since: Date?, limit: Int) async throws -> [FriendReactionNotification] {
        let rows: [IncomingReactionRow] = try await client.request(
            path: "reactions",
            query: [
                URLQueryItem(name: "select", value: "id,from_user,to_user,reaction_type,created_at"),
                URLQueryItem(name: "to_user", value: "eq.\(userID)"),
                URLQueryItem(name: "from_user", value: "neq.\(userID)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        )
        let profileMap = Dictionary(
            uniqueKeysWithValues: try await profiles(ids: Array(Set(rows.map(\.fromUser)))).map { ($0.id, $0) }
        )
        return rows.compactMap { row in
            guard let kind = row.notificationKind else { return nil }
            return FriendReactionNotification(
                id: row.id,
                fromUserID: row.fromUser,
                fromDisplayName: profileMap[row.fromUser]?.displayName ?? L("Znajomy"),
                kind: kind,
                createdAt: row.createdAt.supabaseDate
            )
        }
    }

    func block(_ userID: String, as viewer: String) async throws {
        try await client.request(
            path: "user_blocks",
            method: .post,
            body: BlockInsert(blocker: viewer, blocked: userID),
            prefer: "resolution=ignore-duplicates,return=minimal"
        )
    }

    func unblock(_ userID: String, as viewer: String) async throws {
        try await client.request(
            path: "user_blocks",
            method: .delete,
            query: [
                URLQueryItem(name: "blocker", value: "eq.\(viewer)"),
                URLQueryItem(name: "blocked", value: "eq.\(userID)"),
            ]
        )
    }

    func blockedUserIDs(for viewer: String) async throws -> Set<String> {
        let rows: [BlockRow] = try await client.request(
            path: "user_blocks",
            query: [
                URLQueryItem(name: "select", value: "blocked"),
                URLQueryItem(name: "blocker", value: "eq.\(viewer)"),
            ]
        )
        return Set(rows.map(\.blocked))
    }

    func report(_ userID: String, reason: String, as viewer: String) async throws {
        try await client.request(
            path: "moderation_reports",
            method: .post,
            body: ReportInsert(reporter: viewer, reported: userID, reason: reason),
            prefer: "return=minimal"
        )
    }

    private func friendshipRows(userID: String, extra: [URLQueryItem]) async throws -> [FriendshipRow] {
        try await client.request(
            path: "friendships",
            query: [
                URLQueryItem(name: "select", value: "id,user_a,user_b,status,requested_by,requested_at,accepted_at"),
                URLQueryItem(name: "or", value: "(user_a.eq.\(userID),user_b.eq.\(userID))"),
            ] + extra
        )
    }

    private func pairRow(userID: String, friendID: String) async throws -> FriendshipRow? {
        let pair = Self.orderedPair(userID, friendID)
        let rows: [FriendshipRow] = try await client.request(
            path: "friendships",
            query: [
                URLQueryItem(name: "select", value: "id,user_a,user_b,status,requested_by,requested_at,accepted_at"),
                URLQueryItem(name: "user_a", value: "eq.\(pair.0)"),
                URLQueryItem(name: "user_b", value: "eq.\(pair.1)"),
                URLQueryItem(name: "limit", value: "1"),
            ]
        )
        return rows.first
    }

    private func hydrateEvents(_ rows: [ActivityEventRow], viewerID: String) async throws -> [FeedEvent] {
        let profileMap = Dictionary(
            uniqueKeysWithValues: try await profiles(ids: Array(Set(rows.map(\.userID)))).map { ($0.id, $0) })
        let reactions = try await reactions(for: rows.map(\.id), viewerID: viewerID)
        return rows.compactMap { row in
            guard let kind = FeedEventKind(rawValue: row.eventType) else { return nil }
            let profile = profileMap[row.userID]
            let eventReactions = reactions[row.id] ?? []
            return FeedEvent(
                id: row.id,
                actorID: row.userID,
                actorDisplayName: profile?.displayName ?? row.eventData.title ?? L("Znajomy"),
                actorAvatarURL: profile?.avatarURL,
                kind: kind,
                payload: row.eventData.summary ?? row.eventData.title ?? kind.rawValue,
                createdAt: row.createdAtDate,
                reactions: Dictionary(grouping: eventReactions.compactMap(\.kind), by: { $0 }).mapValues(\.count),
                myReaction: eventReactions.first(where: { $0.fromUser == viewerID })?.kind
            )
        }
    }

    private static func orderedPair(_ lhs: String, _ rhs: String) -> (String, String) {
        lhs < rhs ? (lhs, rhs) : (rhs, lhs)
    }

    private static func extractCode(_ code: String) -> String {
        if let url = URL(string: code), url.scheme == "fitgram", url.host == "friend" {
            return url.pathComponents.dropFirst().first ?? code
        }
        return code.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension SupabaseFriendService {
    fileprivate func withCounterparts(_ requests: [FriendRequest], viewer: String) async throws -> [FriendRequest] {
        let otherIDs = requests.map { $0.fromUserID == viewer ? $0.toUserID : $0.fromUserID }
        let byID = Dictionary(uniqueKeysWithValues: try await profiles(ids: Array(Set(otherIDs))).map { ($0.id, $0) })
        return requests.map { request in
            var copy = request
            copy.counterpart = byID[request.fromUserID == viewer ? request.toUserID : request.fromUserID]
            return copy
        }
    }

    fileprivate func profiles(ids: [String]) async throws -> [PublicProfile] {
        guard !ids.isEmpty else { return [] }
        let rows: [PublicProfileRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: PublicProfileRow.selectColumns),
                URLQueryItem(name: "user_id", value: "in.(\(ids.joined(separator: ",")))"),
            ]
        )
        return rows.map(\.toPublicProfile)
    }

    fileprivate func reactions(for eventIDs: [UUID], viewerID: String) async throws -> [UUID: [ReactionRow]] {
        guard !eventIDs.isEmpty else { return [:] }
        let rows: [ReactionRow] = try await client.request(
            path: "reactions",
            query: [
                URLQueryItem(name: "select", value: "from_user,event_id,reaction_type"),
                URLQueryItem(
                    name: "event_id",
                    value: "in.(\(eventIDs.map(\.uuidString).joined(separator: ",")))"
                ),
            ]
        )
        return Dictionary(grouping: rows.filter { $0.eventID != nil }) { $0.eventID ?? UUID() }
    }
}
