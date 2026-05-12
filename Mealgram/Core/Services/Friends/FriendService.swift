import Foundation

/// What every concrete friends backend has to deliver. The real impl is a
/// Supabase-backed `SupabaseFriendService` (lands when the URL + anon key
/// arrive); for development + tests we use `InMemoryFriendService`.
///
/// Methods are intentionally chunked the way the UI consumes them — one
/// call per screen rather than a single graph query — so the in-memory
/// stub stays trivial and the eventual SQL boundary maps 1-to-1.
@MainActor
protocol FriendService: Sendable {
    /// Profiles of accepted friends, alphabetised by displayName.
    func friends(of userID: String) async throws -> [PublicProfile]

    /// Friend requests waiting on `userID` to accept/reject.
    func pendingIncoming(for userID: String) async throws -> [FriendRequest]

    /// Friend requests `userID` sent that are still pending.
    func pendingOutgoing(for userID: String) async throws -> [FriendRequest]

    /// Username / display-name search. Free-text; case-insensitive.
    /// Returns at most a few hits.
    func search(query: String, excluding userID: String) async throws -> [PublicProfile]

    /// Resolve a deep-link / QR-encoded user identifier into a profile.
    func profile(forCode code: String) async throws -> PublicProfile

    /// Initiates a friend request. Idempotent on already-pending.
    func sendRequest(from: String, to: String) async throws -> FriendRequest

    /// Accept an incoming request. Server pairs both rows.
    func accept(request: FriendRequest, as userID: String) async throws

    /// Reject (or cancel-own) request.
    func reject(request: FriendRequest, as userID: String) async throws

    /// Drops the friendship. Symmetric.
    func unfriend(_ friendID: String, as userID: String) async throws

    /// Most-recent friend activity events, newest first. Real backend
    /// streams via Supabase Realtime; this is a pull-snapshot.
    func recentFeed(for userID: String, limit: Int) async throws -> [FeedEvent]

    /// Reactions are toggles — passing `nil` removes the current user's
    /// reaction.
    func react(to event: FeedEvent, as userID: String, kind: ReactionKind?) async throws -> FeedEvent
}
