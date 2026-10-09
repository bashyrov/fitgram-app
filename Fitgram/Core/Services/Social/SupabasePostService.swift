import Foundation

/// Posts + likes on Supabase (`posts`, `post_likes`, storage bucket
/// `post-photos`). RLS decides who sees what; a trigger enforces Premium
/// and the daily limit, so the client checks are only a fast path.
@MainActor
final class SupabasePostService: PostService {
    static let bucket = "post-photos"

    private let client: SupabaseRESTClient
    private let calendar: Calendar

    init?(client: SupabaseRESTClient? = SupabaseRESTClient(), calendar: Calendar = .current) {
        guard let client else { return nil }
        self.client = client
        self.calendar = calendar
    }

    func feed(authorIDs: [String], viewer: String, limit: Int) async throws -> [SocialPost] {
        let ids = Array(Set(authorIDs.filter { UUID(uuidString: $0) != nil }))
        guard !ids.isEmpty else { return [] }
        let rows: [PostRow] = try await client.request(
            path: "posts",
            query: [
                URLQueryItem(name: "select", value: PostRow.selectColumns),
                URLQueryItem(name: "user_id", value: "in.(\(ids.joined(separator: ",")))"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
        )
        return try await hydrate(rows, viewer: viewer)
    }

    func posts(by authorID: String, viewer: String) async throws -> AuthorPosts {
        guard UUID(uuidString: authorID) != nil else { return AuthorPosts(posts: [], isHidden: false) }
        let canView: Bool = try await client.request(
            path: "rpc/can_view_posts",
            method: .post,
            body: ViewerOwnerArgs(viewer: viewer, owner: authorID)
        )
        guard canView else { return AuthorPosts(posts: [], isHidden: true) }
        let rows: [PostRow] = try await client.request(
            path: "posts",
            query: [
                URLQueryItem(name: "select", value: PostRow.selectColumns),
                URLQueryItem(name: "user_id", value: "eq.\(authorID)"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "50"),
            ]
        )
        return AuthorPosts(posts: try await hydrate(rows, viewer: viewer), isHidden: false)
    }

    func create(_ draft: PostDraft, as author: PublicProfile, isPremium: Bool) async throws -> SocialPost {
        let now = Date()
        let today: Int
        do {
            today = try await postCount(by: author.id, on: now, calendar: calendar)
        } catch let SupabaseRESTClient.SupabaseError.http(_, body) {
            throw Self.mapServerError(body)
        }
        try validate(draft, isPremium: isPremium, publishedToday: today)
        var photoPath: String?
        if let jpeg = draft.photoJPEG {
            let path = "\(author.id.lowercased())/\(UUID().uuidString.lowercased()).jpg"
            do {
                try await client.uploadObject(bucket: Self.bucket, path: path, data: jpeg, contentType: "image/jpeg")
            } catch let SupabaseRESTClient.SupabaseError.http(status, body) {
                throw PostError.photoUpload("\(status) \(Self.serverMessage(body))")
            }
            photoPath = path
        }
        do {
            let rows: [PostRow] = try await client.request(
                path: "posts",
                method: .post,
                query: [URLQueryItem(name: "select", value: PostRow.selectColumns)],
                body: PostInsert(
                    userID: author.id,
                    title: draft.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    body: draft.body.trimmingCharacters(in: .whitespacesAndNewlines),
                    photoPath: photoPath,
                    macros: draft.macros,
                    activity: draft.activity,
                    localDay: Self.dayString(now, calendar: calendar)
                ),
                prefer: "return=representation"
            )
            guard let row = rows.first else { throw PostError.network("Empty post response") }
            return row.toPost(author: author, photoURL: photoURL(row.photoPath), likes: [], viewer: author.id)
        } catch let SupabaseRESTClient.SupabaseError.http(_, body) {
            if let photoPath { try? await client.deleteObject(bucket: Self.bucket, path: photoPath) }
            throw Self.mapServerError(body)
        }
    }

    func setLiked(_ liked: Bool, postID: UUID, viewer: String) async throws {
        if liked {
            try await client.request(
                path: "post_likes",
                method: .post,
                body: PostLikeInsert(postID: postID, userID: viewer),
                prefer: "resolution=ignore-duplicates,return=minimal"
            )
        } else {
            try await client.request(
                path: "post_likes",
                method: .delete,
                query: [
                    URLQueryItem(name: "post_id", value: "eq.\(postID.uuidString)"),
                    URLQueryItem(name: "user_id", value: "eq.\(viewer)"),
                ]
            )
        }
    }

    func delete(postID: UUID, as viewer: String) async throws {
        let rows: [PostRow] = try await client.request(
            path: "posts",
            method: .delete,
            query: [
                URLQueryItem(name: "id", value: "eq.\(postID.uuidString)"),
                URLQueryItem(name: "user_id", value: "eq.\(viewer)"),
                URLQueryItem(name: "select", value: PostRow.selectColumns),
            ],
            prefer: "return=representation"
        )
        if let path = rows.first?.photoPath {
            try? await client.deleteObject(bucket: Self.bucket, path: path)
        }
    }

    func postCount(by authorID: String, on day: Date, calendar: Calendar) async throws -> Int {
        guard UUID(uuidString: authorID) != nil else { return 0 }
        let rows: [PostIDRow] = try await client.request(
            path: "posts",
            query: [
                URLQueryItem(name: "select", value: "id"),
                URLQueryItem(name: "user_id", value: "eq.\(authorID)"),
                URLQueryItem(name: "local_day", value: "eq.\(Self.dayString(day, calendar: calendar))"),
                URLQueryItem(name: "limit", value: "\(PostLimits.dailyMax + 1)"),
            ]
        )
        return rows.count
    }

    // MARK: - Helpers

    private func hydrate(_ rows: [PostRow], viewer: String) async throws -> [SocialPost] {
        guard !rows.isEmpty else { return [] }
        let authorIDs = Array(Set(rows.map(\.userID)))
        let profileRows: [PublicProfileRow] = try await client.request(
            path: "public_profiles",
            query: [
                URLQueryItem(name: "select", value: PublicProfileRow.selectColumns),
                URLQueryItem(name: "user_id", value: "in.(\(authorIDs.joined(separator: ",")))"),
            ]
        )
        let authors = Dictionary(uniqueKeysWithValues: profileRows.map { ($0.userID, $0.toPublicProfile) })
        let likeRows: [PostLikeRow] = try await client.request(
            path: "post_likes",
            query: [
                URLQueryItem(name: "select", value: "post_id,user_id"),
                URLQueryItem(name: "post_id", value: "in.(\(rows.map(\.id.uuidString).joined(separator: ",")))"),
            ]
        )
        let likesByPost = Dictionary(grouping: likeRows, by: \.postID)
        return rows.compactMap { row in
            guard let author = authors[row.userID] else { return nil }
            return row.toPost(
                author: author,
                photoURL: photoURL(row.photoPath),
                likes: (likesByPost[row.id] ?? []).map(\.userID),
                viewer: viewer
            )
        }
    }

    private func photoURL(_ path: String?) -> URL? {
        path.map { client.publicObjectURL(bucket: Self.bucket, path: $0) }
    }

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 1970, parts.month ?? 1, parts.day ?? 1)
    }

    static func mapServerError(_ body: String) -> PostError {
        if body.contains("daily_post_limit") { return .dailyLimitReached }
        if body.contains("premium_required") { return .premiumRequired }
        if body.contains("posts_one_attachment") { return .oneAttachmentOnly }
        if body.contains("check constraint") { return .contentRejected }
        return .network(serverMessage(body))
    }

    /// The `message` field of a PostgREST / Storage error body, or the body.
    static func serverMessage(_ body: String) -> String {
        if let data = body.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = json["message"] as? String
        {
            return message
        }
        return String(body.prefix(160))
    }
}

// MARK: - Rows

struct PostRow: Decodable, Sendable {
    let id: UUID
    let userID: String
    let title: String
    let body: String
    let photoPath: String?
    let macros: PostMacroSnapshot?
    let activity: PostActivitySnapshot?
    let createdAt: String

    static let selectColumns = "id,user_id,title,body,photo_path,macros,activity,created_at"

    private enum CodingKeys: String, CodingKey {
        case id
        case userID = "userId"
        case title
        case body
        case photoPath
        case macros
        case activity
        case createdAt
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        userID = try container.decode(String.self, forKey: .userID)
        title = try container.decode(String.self, forKey: .title)
        body = try container.decodeIfPresent(String.self, forKey: .body) ?? ""
        photoPath = try container.decodeIfPresent(String.self, forKey: .photoPath)
        // A malformed macros blob must not hide the whole post.
        macros = try? container.decodeIfPresent(PostMacroSnapshot.self, forKey: .macros)
        activity = try? container.decodeIfPresent(PostActivitySnapshot.self, forKey: .activity)
        createdAt = try container.decode(String.self, forKey: .createdAt)
    }

    func toPost(author: PublicProfile, photoURL: URL?, likes: [String], viewer: String) -> SocialPost {
        SocialPost(
            id: id,
            authorID: userID,
            authorName: author.displayName,
            authorUsername: author.username,
            authorIsPremium: author.isPremium,
            title: title,
            body: body,
            photoURL: photoURL,
            macros: macros,
            activity: activity,
            createdAt: createdAt.supabaseDate,
            likeCount: likes.count,
            isLikedByMe: likes.contains(viewer)
        )
    }
}

private struct PostIDRow: Decodable, Sendable {
    let id: UUID
}

private struct PostLikeRow: Decodable, Sendable {
    let postID: UUID
    let userID: String

    private enum CodingKeys: String, CodingKey {
        case postID = "postId"
        case userID = "userId"
    }
}

private struct PostInsert: Encodable {
    let userID: String
    let title: String
    let body: String
    let photoPath: String?
    let macros: PostMacroSnapshot?
    let activity: PostActivitySnapshot?
    let localDay: String
}

private struct PostLikeInsert: Encodable {
    let postID: UUID
    let userID: String
}
