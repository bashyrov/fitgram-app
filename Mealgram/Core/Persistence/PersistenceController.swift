import Foundation
import OSLog
import SwiftData

/// Wraps the app's `ModelContainer`. One source of truth — feature code asks
/// `PersistenceController.shared.container` (or the `.preview` variant when
/// driving SwiftUI previews). Tests build their own in-memory container via
/// the `makeInMemory()` factory so they never collide with the on-disk
/// store.
@MainActor
final class PersistenceController {
    static let shared: PersistenceController = {
        do {
            return try PersistenceController(inMemory: false)
        } catch {
            Logger.persistence.fault("Failed to open on-disk store: \(String(describing: error))")
            // Fall back to an in-memory container so the app still boots
            // and surfaces an empty state rather than crashing. The error
            // is logged and we'll add a UI surface in Milestone 5.2.
            return PersistenceController.fallback()
        }
    }()

    let container: ModelContainer

    init(inMemory: Bool) throws {
        let schema = Schema(versionedSchema: MealgramSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        self.container = try ModelContainer(for: schema, configurations: [configuration])
    }

    /// In-memory factory for tests + previews — never persists between runs.
    static func makeInMemory() throws -> PersistenceController {
        try PersistenceController(inMemory: true)
    }

    /// Last-resort fallback used by `shared` when the disk store fails. Keeps
    /// the schema identical so reads / writes from feature code don't have
    /// to branch.
    private static func fallback() -> PersistenceController {
        do {
            return try PersistenceController(inMemory: true)
        } catch {
            // If even an in-memory container can't be created the runtime
            // is fundamentally broken — there's nothing meaningful we can
            // recover from, so a crash here is the honest signal.
            fatalError("Failed to create in-memory ModelContainer: \(error)")
        }
    }

    /// Drops every persistent model from the live container — used by
    /// `AccountDeletionService`. The container itself stays alive.
    func wipeAllData() throws {
        let context = ModelContext(container)
        for modelType in MealgramSchemaV1.models {
            try context.delete(model: modelType)
        }
        try context.save()
    }
}
