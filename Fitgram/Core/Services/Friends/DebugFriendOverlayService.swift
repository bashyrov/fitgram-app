#if DEBUG
import Foundation

@MainActor
final class DebugFriendOverlayService: FriendService {
    private let base: any FriendService
    private var demosByUserID: [String: InMemoryFriendService] = [:]

    /// The real backend failing (offline, no session in screenshot runs)
    /// must not hide the demo people, so base reads are best-effort.
    init(base: any FriendService) {
        self.base = base
    }

    func friends(of userID: String) async throws -> [PublicProfile] {
        let baseFriends = (try? await base.friends(of: userID)) ?? []
        let demoFriends = try await demo(for: userID).friends(of: userID)
        let merged = baseFriends + demoFriends
        return uniqueProfiles(merged).sorted { $0.displayName < $1.displayName }
    }

    func pendingIncoming(for userID: String) async throws -> [FriendRequest] {
        let baseRequests = (try? await base.pendingIncoming(for: userID)) ?? []
        let demoRequests = try await demo(for: userID).pendingIncoming(for: userID)
        return baseRequests + demoRequests
    }

    func pendingOutgoing(for userID: String) async throws -> [FriendRequest] {
        let baseRequests = (try? await base.pendingOutgoing(for: userID)) ?? []
        let demoRequests = try await demo(for: userID).pendingOutgoing(for: userID)
        return baseRequests + demoRequests
    }

    func search(query: String, excluding userID: String) async throws -> [PublicProfile] {
        let baseResults = (try? await base.search(query: query, excluding: userID)) ?? []
        let demoResults = try await demo(for: userID).search(query: query, excluding: userID)
        let merged = baseResults + demoResults
        return uniqueProfiles(merged).sorted { $0.displayName < $1.displayName }
    }

    func profile(forCode code: String) async throws -> PublicProfile {
        let cleaned = code.replacingOccurrences(of: "fitgram://friend/", with: "")
        for demo in demosByUserID.values {
            if let profile = try? await demo.profile(forCode: cleaned) {
                return profile
            }
        }
        if let profile = try? await InMemoryFriendService().profile(forCode: cleaned) {
            return profile
        }
        return try await base.profile(forCode: code)
    }

    func sendRequest(from: String, to: String) async throws -> FriendRequest {
        let localDemo = demo(for: from)
        if (try? await localDemo.profile(forCode: to)) != nil {
            let request = try await localDemo.sendRequest(from: from, to: to)
            try? await localDemo.accept(request: request, as: to)
            return request
        }
        return try await base.sendRequest(from: from, to: to)
    }

    func accept(request: FriendRequest, as userID: String) async throws {
        if let demo = await demoContaining(request: request) {
            try await demo.accept(request: request, as: userID)
            return
        }
        try await base.accept(request: request, as: userID)
    }

    func reject(request: FriendRequest, as userID: String) async throws {
        if let demo = await demoContaining(request: request) {
            try await demo.reject(request: request, as: userID)
            return
        }
        try await base.reject(request: request, as: userID)
    }

    func unfriend(_ friendID: String, as userID: String) async throws {
        if (try? await demo(for: userID).profile(forCode: friendID)) != nil {
            try await demo(for: userID).unfriend(friendID, as: userID)
            return
        }
        try await base.unfriend(friendID, as: userID)
    }

    func recentFeed(for userID: String, limit: Int) async throws -> [FeedEvent] {
        let baseFeed = (try? await base.recentFeed(for: userID, limit: limit)) ?? []
        let demoFeed = try await demo(for: userID).recentFeed(for: userID, limit: limit)
        let merged = baseFeed + demoFeed
        return Array(merged.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func react(to event: FeedEvent, as userID: String, kind: ReactionKind?) async throws -> FeedEvent {
        if let updated = try? await demo(for: userID).react(to: event, as: userID, kind: kind) {
            return updated
        }
        return try await base.react(to: event, as: userID, kind: kind)
    }

    func snapshot(forUserID userID: String, viewer: String) async throws -> FriendProfileSnapshot {
        if let snapshot = try? await demo(for: viewer).snapshot(forUserID: userID, viewer: viewer) {
            return snapshot
        }
        return try await base.snapshot(forUserID: userID, viewer: viewer)
    }

    func sendPositiveReaction(to userID: String, from viewer: String, intent: PositiveReactionIntent) async throws {
        if (try? await demo(for: viewer).snapshot(forUserID: userID, viewer: viewer)) != nil {
            try await demo(for: viewer).sendPositiveReaction(to: userID, from: viewer, intent: intent)
            return
        }
        try await base.sendPositiveReaction(to: userID, from: viewer, intent: intent)
    }

    func incomingReactions(for userID: String, since: Date?, limit: Int) async throws -> [FriendReactionNotification] {
        let baseReactions = (try? await base.incomingReactions(for: userID, since: since, limit: limit)) ?? []
        let demoReactions = try await demo(for: userID).incomingReactions(for: userID, since: since, limit: limit)
        let merged = baseReactions + demoReactions
        return Array(merged.sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func block(_ userID: String, as viewer: String) async throws {
        try await base.block(userID, as: viewer)
    }

    func unblock(_ userID: String, as viewer: String) async throws {
        try await base.unblock(userID, as: viewer)
    }

    func blockedUserIDs(for viewer: String) async throws -> Set<String> {
        try await base.blockedUserIDs(for: viewer)
    }

    func report(_ userID: String, reason: String, as viewer: String) async throws {
        try await base.report(userID, reason: reason, as: viewer)
    }

    /// Post visibility for the demo people, following the demo friend graph.
    func canViewDemoPosts(of authorID: String, viewer: String) -> Bool {
        demo(for: viewer).canViewPosts(of: authorID, viewer: viewer)
    }

    private func demo(for userID: String) -> InMemoryFriendService {
        if let existing = demosByUserID[userID] {
            return existing
        }
        let created = InMemoryFriendService(seedFor: userID)
        demosByUserID[userID] = created
        return created
    }

    private func demoContaining(request: FriendRequest) async -> InMemoryFriendService? {
        for demo in demosByUserID.values {
            let hasSender = (try? await demo.profile(forCode: request.fromUserID)) != nil
            let hasReceiver = (try? await demo.profile(forCode: request.toUserID)) != nil
            if hasSender || hasReceiver {
                return demo
            }
        }
        return nil
    }

    private func uniqueProfiles(_ profiles: [PublicProfile]) -> [PublicProfile] {
        var seen: Set<String> = []
        return profiles.filter { profile in
            guard !seen.contains(profile.id) else { return false }
            seen.insert(profile.id)
            return true
        }
    }
}
#endif
