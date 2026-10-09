import Foundation

/// Friends' posts: text, optional photo and macros, plus likes. Only
/// Premium users can publish, at most `PostLimits.dailyMax` per day; both
/// rules are checked here and again by the backend.
@MainActor
protocol PostService: Sendable {
    /// Newest posts written by `authorIDs` (the viewer's friends and the
    /// viewer), as the viewer is allowed to see them.
    func feed(authorIDs: [String], viewer: String, limit: Int) async throws -> [SocialPost]

    /// One author's posts, newest first, honouring their privacy settings.
    func posts(by authorID: String, viewer: String) async throws -> AuthorPosts

    /// Publishes a post. Throws `PostError.premiumRequired` /
    /// `.dailyLimitReached` / `.contentRejected`.
    func create(_ draft: PostDraft, as author: PublicProfile, isPremium: Bool) async throws -> SocialPost

    func setLiked(_ liked: Bool, postID: UUID, viewer: String) async throws

    func delete(postID: UUID, as viewer: String) async throws

    /// How many posts `authorID` published on the calendar day of `day`.
    func postCount(by authorID: String, on day: Date, calendar: Calendar) async throws -> Int
}

extension PostService {
    /// Shared pre-flight for every implementation.
    func validate(_ draft: PostDraft, isPremium: Bool, publishedToday: Int) throws {
        guard isPremium else { throw PostError.premiumRequired }
        guard publishedToday < PostLimits.dailyMax else { throw PostError.dailyLimitReached }
        guard PostContentPolicy.violations(title: draft.title, body: draft.body).isEmpty else {
            throw PostError.contentRejected
        }
    }
}

/// Process-local posts used for demo friends, previews and tests.
@MainActor
final class InMemoryPostService: PostService {
    private var posts: [SocialPost]
    private var likes: [UUID: Set<String>]
    private let now: () -> Date
    /// Who may read whose posts — `(author, viewer)`. Defaults to everyone;
    /// the app plugs in the demo friend graph.
    var visibilityRule: @MainActor (String, String) -> Bool = { _, _ in true }

    init(seeded: Bool = true, now: @escaping () -> Date = Date.init) {
        self.now = now
        let seed = seeded ? Self.seedPosts(now: now()) : (posts: [], likes: [:])
        self.posts = seed.posts
        self.likes = seed.likes
    }

    func feed(authorIDs: [String], viewer: String, limit: Int) async throws -> [SocialPost] {
        let allowed = Set(authorIDs)
        return
            posts
            .filter { allowed.contains($0.authorID) && canView($0.authorID, viewer: viewer) }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { hydrate($0, viewer: viewer) }
    }

    func posts(by authorID: String, viewer: String) async throws -> AuthorPosts {
        guard canView(authorID, viewer: viewer) else { return AuthorPosts(posts: [], isHidden: true) }
        let mine =
            posts
            .filter { $0.authorID == authorID }
            .sorted { $0.createdAt > $1.createdAt }
            .map { hydrate($0, viewer: viewer) }
        return AuthorPosts(posts: mine, isHidden: false)
    }

    func create(_ draft: PostDraft, as author: PublicProfile, isPremium: Bool) async throws -> SocialPost {
        let today = try await postCount(by: author.id, on: now(), calendar: .current)
        try validate(draft, isPremium: isPremium, publishedToday: today)
        let post = SocialPost(
            id: UUID(),
            authorID: author.id,
            authorName: author.displayName,
            authorUsername: author.username,
            authorIsPremium: true,
            title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
            body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
            photoURL: draft.photoJPEG.flatMap(Self.writeTemporaryPhoto),
            macros: draft.macros,
            createdAt: now(),
            likeCount: 0,
            isLikedByMe: false
        )
        posts.append(post)
        return post
    }

    func setLiked(_ liked: Bool, postID: UUID, viewer: String) async throws {
        guard posts.contains(where: { $0.id == postID }) else { throw PostError.notFound }
        if liked {
            likes[postID, default: []].insert(viewer)
        } else {
            likes[postID]?.remove(viewer)
        }
    }

    func delete(postID: UUID, as viewer: String) async throws {
        guard let index = posts.firstIndex(where: { $0.id == postID }) else { throw PostError.notFound }
        guard posts[index].authorID == viewer else { throw PostError.notFound }
        posts.remove(at: index)
        likes[postID] = nil
    }

    func postCount(by authorID: String, on day: Date, calendar: Calendar) async throws -> Int {
        posts.filter { $0.authorID == authorID && calendar.isDate($0.createdAt, inSameDayAs: day) }.count
    }

    func contains(postID: UUID) -> Bool {
        posts.contains { $0.id == postID }
    }

    private func canView(_ authorID: String, viewer: String) -> Bool {
        authorID == viewer || visibilityRule(authorID, viewer)
    }

    private func hydrate(_ post: SocialPost, viewer: String) -> SocialPost {
        var copy = post
        let likers = likes[post.id] ?? []
        copy.likeCount = likers.count
        copy.isLikedByMe = likers.contains(viewer)
        return copy
    }

    private static func writeTemporaryPhoto(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("post-\(UUID().uuidString).jpg")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

@MainActor
enum PostServiceFactory {
    /// Picks the post backend that matches the friends backend, so demo
    /// friends get demo posts and real friends real ones.
    static func make(for friendService: any FriendService) -> any PostService {
        #if DEBUG
        if let overlay = friendService as? DebugFriendOverlayService {
            let demo = InMemoryPostService()
            demo.visibilityRule = { [weak overlay] author, viewer in
                overlay?.canViewDemoPosts(of: author, viewer: viewer) ?? true
            }
            return DebugPostOverlayService(base: SupabasePostService(), demo: demo)
        }
        #endif
        if let local = friendService as? InMemoryFriendService {
            let demo = InMemoryPostService()
            demo.visibilityRule = { [weak local] author, viewer in
                local?.canViewPosts(of: author, viewer: viewer) ?? true
            }
            return demo
        }
        return SupabasePostService() ?? InMemoryPostService(seeded: false)
    }
}
