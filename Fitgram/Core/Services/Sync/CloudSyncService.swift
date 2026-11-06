import Foundation
import OSLog
import SwiftData
import UIKit

/// Mirrors the signed-in account's data to Supabase (`public.user_records`) so
/// it follows the account to another iPhone or a reinstall.
///
/// Each pass pulls the server's changes first, then pushes local ones:
/// - Pull reads rows changed since the stored cursor (server `updated_at`)
///   and creates, updates or deletes the matching local records.
/// - Push encodes every local record, compares its hash with the last one
///   synced, upserts the changed ones and sends a tombstone for records that
///   disappeared locally.
/// Last write wins per record. Without Supabase or a real session (debug
/// builds, signed out) a pass is a no-op.
@MainActor
final class CloudSyncService {
    static let tables: [SyncTable] = [
        SyncTable(ProfileRecord.self),
        SyncTable(MealRecord.self),
        SyncTable(RecipeRecord.self),
        SyncTable(CustomFoodRecord.self),
        SyncTable(WeightRecord.self),
        SyncTable(WaterRecord.self),
        SyncTable(WorkoutRecord.self),
        SyncTable(FavoriteMealRecord.self),
        SyncTable(CustomGoalRecord.self),
        SyncTable(StreakRecord.self),
        SyncTable(CalibrationRecord.self),
        SyncTable(AchievementRecord.self),
        SyncTable(CoachMemoryRecord.self),
        SyncTable(CoachInsightRecord.self),
    ]

    private static let pageSize = 500
    private static let pushChunk = 200

    private let container: ModelContainer
    private let makeTransport: () -> (any CloudSyncTransport)?
    private let stateStore: CloudSyncStateStore
    private var isSyncing = false
    private var needsAnotherPass = false
    private var pending: Task<Void, Never>?
    private var mealObserver: NSObjectProtocol?

    init(
        container: ModelContainer,
        stateStore: CloudSyncStateStore = CloudSyncStateStore(),
        makeTransport: @escaping () -> (any CloudSyncTransport)? = SupabaseSyncTransport.init
    ) {
        self.container = container
        self.stateStore = stateStore
        self.makeTransport = makeTransport
        mealObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("FitgramMealSaved"), object: nil, queue: .main
        ) { [weak self] note in
            // Our own pull posts this too; only local saves need a push.
            guard note.object == nil else { return }
            MainActor.assumeIsolated { self?.requestSync() }
        }
    }

    /// Debounced pass for the signed-in account.
    func requestSync(after delay: Duration = .seconds(3)) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            let owner = AccountScope.currentUserID
            guard !owner.isEmpty else { return }
            await self.sync(owner: owner)
        }
    }

    /// Pass started as the app goes to the background; iOS grants a little
    /// extra time to finish it.
    func syncBeforeBackground() {
        let owner = AccountScope.currentUserID
        guard !owner.isEmpty else { return }
        pending?.cancel()
        var taskID = UIBackgroundTaskIdentifier.invalid
        taskID = UIApplication.shared.beginBackgroundTask(withName: "CloudSync") {
            UIApplication.shared.endBackgroundTask(taskID)
        }
        Task {
            await sync(owner: owner)
            UIApplication.shared.endBackgroundTask(taskID)
        }
    }

    /// Run at sign-in before the account is shown, so a fresh install opens
    /// with the history (and skips onboarding) instead of an empty diary.
    /// Gives up after `timeout`; the next pass picks up where it stopped.
    func syncBeforeShowing(_ owner: String, timeout: Duration = .seconds(12)) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.sync(owner: owner) }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
    }

    func sync(owner: String) async {
        guard !owner.isEmpty else { return }
        guard !isSyncing else {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherPass = false
            await performPass(owner: owner)
        } while needsAnotherPass && !Task.isCancelled
    }

    // MARK: - Pass

    private func performPass(owner: String) async {
        guard let client = makeTransport() else { return }
        var state = stateStore.load(owner)
        do {
            let changed = try await pull(owner: owner, client: client, state: &state)
            stateStore.save(state, for: owner)
            try await push(owner: owner, client: client, state: &state)
            if changed { announceChanges(owner: owner) }
        } catch SupabaseRESTClient.SupabaseError.unauthorized {
            // No session (signed out, debug user): nothing to sync.
        } catch is CancellationError {
        } catch let error as URLError where error.code == .cancelled {
        } catch {
            Logger.persistence.error("Cloud sync failed: \(String(describing: error), privacy: .public)")
        }
        stateStore.save(state, for: owner)
    }

    private func pull(owner: String, client: any CloudSyncTransport, state: inout CloudSyncState) async throws -> Bool {
        let tables = Dictionary(uniqueKeysWithValues: Self.tables.map { ($0.kind, $0) })
        var changed = false
        while true {
            let rows = try await client.fetchChanges(owner: owner, after: state.cursor, limit: Self.pageSize)
            guard let last = rows.last else { break }

            let context = ModelContext(container)
            for row in rows {
                guard let table = tables[row.kind] else { continue }
                if row.deleted {
                    try table.delete(row.id, owner, context)
                    state.pushed[row.kind]?[row.id] = nil
                    changed = true
                    continue
                }
                let payload = Data(row.payload.utf8)
                let hash = SyncCoding.hash(payload)
                guard state.pushed[row.kind]?[row.id] != hash else { continue }
                try table.apply(row.id, payload, owner, context)
                state.pushed[row.kind, default: [:]][row.id] = hash
                changed = true
            }
            try context.save()
            state.cursor = last.updatedAt
            if rows.count < Self.pageSize { break }
        }
        return changed
    }

    private func push(owner: String, client: any CloudSyncTransport, state: inout CloudSyncState) async throws {
        let context = ModelContext(container)
        var uploads: [(row: UploadRecord, hash: String?)] = []
        for table in Self.tables {
            let local = try table.snapshot(owner, context)
            let known = state.pushed[table.kind] ?? [:]
            for (id, payload) in local {
                let hash = SyncCoding.hash(payload)
                guard known[id] != hash, let text = String(bytes: payload, encoding: .utf8) else { continue }
                let row = UploadRecord(userID: owner, kind: table.kind, id: id, payload: text, deleted: false)
                uploads.append((row, hash))
            }
            for id in known.keys where local[id] == nil {
                uploads.append((UploadRecord(userID: owner, kind: table.kind, id: id, payload: "", deleted: true), nil))
            }
        }

        var start = 0
        while start < uploads.count {
            let chunk = uploads[start..<min(start + Self.pushChunk, uploads.count)]
            try await client.upsert(chunk.map(\.row))
            for upload in chunk {
                state.pushed[upload.row.kind, default: [:]][upload.row.id] = upload.hash
            }
            stateStore.save(state, for: owner)
            start += Self.pushChunk
        }
    }

    private func announceChanges(owner: String) {
        // Today / Week refresh on a meal save; caches keyed to the account
        // (food catalogue, counters) reload on an account change.
        NotificationCenter.default.post(
            name: Notification.Name("FitgramMealSaved"), object: self, userInfo: ["userRemoteID": owner])
        NotificationCenter.default.post(name: .fitgramAccountDidChange, object: self)
    }
}

// MARK: - Transport

/// The server side of a sync pass. `SupabaseSyncTransport` in the app, an
/// in-memory fake in tests.
protocol CloudSyncTransport: Sendable {
    /// Rows changed after `cursor` (all rows when nil), oldest first.
    func fetchChanges(owner: String, after cursor: String?, limit: Int) async throws -> [RemoteRecord]
    /// Inserts or replaces rows by (user, kind, id).
    func upsert(_ records: [UploadRecord]) async throws
}

struct SupabaseSyncTransport: CloudSyncTransport {
    private let client: SupabaseRESTClient

    init?() {
        guard let client = SupabaseRESTClient(decoder: JSONDecoder(), encoder: JSONEncoder()) else { return nil }
        self.client = client
    }

    func fetchChanges(owner: String, after cursor: String?, limit: Int) async throws -> [RemoteRecord] {
        var query = [
            URLQueryItem(name: "select", value: "kind,id,payload,deleted,updated_at"),
            URLQueryItem(name: "user_id", value: "eq.\(owner)"),
            URLQueryItem(name: "order", value: "updated_at.asc"),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        if let cursor {
            query.append(URLQueryItem(name: "updated_at", value: "gt.\(Self.queryTimestamp(cursor))"))
        }
        return try await client.request(path: "user_records", query: query)
    }

    func upsert(_ records: [UploadRecord]) async throws {
        try await client.request(
            path: "user_records",
            method: .post,
            query: [URLQueryItem(name: "on_conflict", value: "user_id,kind,id")],
            body: records,
            prefer: "resolution=merge-duplicates,return=minimal"
        )
    }

    /// PostgREST reads `+` in a query as a space; the server sends UTC.
    static func queryTimestamp(_ value: String) -> String {
        value.hasSuffix("+00:00") ? String(value.dropLast(6)) + "Z" : value
    }
}

struct RemoteRecord: Decodable, Sendable {
    let kind: String
    let id: String
    let payload: String
    let deleted: Bool
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case kind, id, payload, deleted
        case updatedAt = "updated_at"
    }
}

struct UploadRecord: Encodable, Sendable {
    let userID: String
    let kind: String
    let id: String
    let payload: String
    let deleted: Bool

    enum CodingKeys: String, CodingKey {
        case kind, id, payload, deleted
        case userID = "user_id"
    }
}

// MARK: - State

struct CloudSyncState: Codable, Equatable {
    /// `updated_at` of the newest server row already applied.
    var cursor: String?
    /// `[kind: [id: payload hash]]` of what the server holds, as far as this
    /// device knows. A missing entry means "not on the server yet".
    var pushed: [String: [String: String]] = [:]
}

/// One small JSON file per account under Application Support.
struct CloudSyncStateStore: Sendable {
    let directory: URL

    init(directory: URL? = nil) {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.directory = directory ?? base.appending(path: "CloudSync", directoryHint: .isDirectory)
    }

    func load(_ owner: String) -> CloudSyncState {
        guard let data = try? Data(contentsOf: url(for: owner)),
            let state = try? JSONDecoder().decode(CloudSyncState.self, from: data)
        else { return CloudSyncState() }
        return state
    }

    func save(_ state: CloudSyncState, for owner: String) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url(for: owner), options: .atomic)
        } catch {
            Logger.persistence.error("Saving sync state failed: \(String(describing: error))")
        }
    }

    func remove(_ owner: String) {
        try? FileManager.default.removeItem(at: url(for: owner))
    }

    private func url(for owner: String) -> URL {
        let safe = owner.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return directory.appending(path: "\(safe.isEmpty ? "unknown" : safe).json")
    }
}
