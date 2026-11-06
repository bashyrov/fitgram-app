import CryptoKit
import Foundation
import SwiftData

/// One kind of account data mirrored to `public.user_records`.
///
/// The conforming type is the JSON payload stored on the server; it knows how
/// to read itself from the local model and write itself back. `id` is the
/// row key within the kind: the model's UUID, or a fixed key for per-account
/// singletons (profile, streak, calibration) and per-kind rows (achievements).
@MainActor
protocol SyncedRecord: Codable {
    associatedtype Model: PersistentModel

    static var kind: String { get }
    static func owned(by owner: String, in context: ModelContext) throws -> [Model]
    static func recordID(of model: Model) -> String
    static func find(_ id: String, owner: String, in context: ModelContext) throws -> Model?
    static func insertNew(_ id: String, owner: String, in context: ModelContext) -> Model

    init(_ model: Model)
    func apply(to model: Model, in context: ModelContext)
}

extension SyncedRecord {
    static func fetch(_ predicate: Predicate<Model>, in context: ModelContext) throws -> [Model] {
        try context.fetch(FetchDescriptor<Model>(predicate: predicate))
    }
}

/// Type-erased `SyncedRecord` so the engine can loop over every kind.
@MainActor
struct SyncTable {
    let kind: String
    /// Every record the account owns locally, as `[id: payload]`.
    let snapshot: (_ owner: String, _ context: ModelContext) throws -> [String: Data]
    /// Creates or updates the local record from a server payload.
    let apply: (_ id: String, _ payload: Data, _ owner: String, _ context: ModelContext) throws -> Void
    /// Removes the local record, if there is one.
    let delete: (_ id: String, _ owner: String, _ context: ModelContext) throws -> Void

    init<Record: SyncedRecord>(_ type: Record.Type) {
        kind = Record.kind
        snapshot = { owner, context in
            var result: [String: Data] = [:]
            for model in try Record.owned(by: owner, in: context) {
                result[Record.recordID(of: model)] = try SyncCoding.encoder.encode(Record(model))
            }
            return result
        }
        apply = { id, payload, owner, context in
            let record = try SyncCoding.decoder.decode(Record.self, from: payload)
            let model =
                try Record.find(id, owner: owner, in: context) ?? Record.insertNew(id, owner: owner, in: context)
            record.apply(to: model, in: context)
        }
        delete = { id, owner, context in
            if let model = try Record.find(id, owner: owner, in: context) {
                context.delete(model)
            }
        }
    }
}

enum SyncCoding {
    /// Stable output (sorted keys, numeric dates) so the same record always
    /// produces the same bytes and therefore the same hash.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }()

    static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
