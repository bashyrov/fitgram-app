#if DEBUG
import Foundation

/// DEBUG builds show the demo friends next to real ones; this routes their
/// posts to the in-memory store and everything else to the real backend.
@MainActor
final class DebugPostOverlayService: PostService {
    private let base: (any PostService)?
    private let demo: InMemoryPostService

    init(base: (any PostService)?, demo: InMemoryPostService) {
        self.base = base
        self.demo = demo
    }

    func feed(authorIDs: [String], viewer: String, limit: Int) async throws -> [SocialPost] {
        let real = (try? await base?.feed(authorIDs: authorIDs, viewer: viewer, limit: limit)) ?? []
        let demoPosts = try await demo.feed(authorIDs: authorIDs, viewer: viewer, limit: limit)
        return Array((real + demoPosts).sorted { $0.createdAt > $1.createdAt }.prefix(limit))
    }

    func posts(by authorID: String, viewer: String) async throws -> AuthorPosts {
        if let base, Self.isReal(authorID) {
            return try await base.posts(by: authorID, viewer: viewer)
        }
        return try await demo.posts(by: authorID, viewer: viewer)
    }

    func create(_ draft: PostDraft, as author: PublicProfile, isPremium: Bool) async throws -> SocialPost {
        if let base, Self.isReal(author.id) {
            return try await base.create(draft, as: author, isPremium: isPremium)
        }
        return try await demo.create(draft, as: author, isPremium: isPremium)
    }

    func setLiked(_ liked: Bool, postID: UUID, viewer: String) async throws {
        if demo.contains(postID: postID) {
            try await demo.setLiked(liked, postID: postID, viewer: viewer)
        } else {
            try await base?.setLiked(liked, postID: postID, viewer: viewer)
        }
    }

    func delete(postID: UUID, as viewer: String) async throws {
        if demo.contains(postID: postID) {
            try await demo.delete(postID: postID, as: viewer)
        } else {
            try await base?.delete(postID: postID, as: viewer)
        }
    }

    func postCount(by authorID: String, on day: Date, calendar: Calendar) async throws -> Int {
        if let base, Self.isReal(authorID) {
            return try await base.postCount(by: authorID, on: day, calendar: calendar)
        }
        return try await demo.postCount(by: authorID, on: day, calendar: calendar)
    }

    private static func isReal(_ userID: String) -> Bool {
        UUID(uuidString: userID) != nil
    }
}
#endif
