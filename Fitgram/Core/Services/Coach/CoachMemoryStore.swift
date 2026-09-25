import Foundation
import OSLog
import SwiftData

/// Read/write surface for the long-lived coach memory notes. The
/// rule-based engine doesn't write notes yet — this is M3.2 prep so
/// the Claude-backed generator can call into a stable API.
@MainActor
final class CoachMemoryStore {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    /// All notes for the user, newest first by updatedAt.
    func notes(forUser userRemoteID: String) -> [CoachMemoryNote] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachMemoryNote>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID },
            sortBy: [SortDescriptor(\CoachMemoryNote.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Notes filtered to one kind — useful for the engine to read
    /// just preferences or just goals when assembling a prompt.
    func notes(
        forUser userRemoteID: String,
        kind: CoachMemoryKind
    ) -> [CoachMemoryNote] {
        let kindRaw = kind.rawValue
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachMemoryNote>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.kindRaw == kindRaw
            },
            sortBy: [SortDescriptor(\CoachMemoryNote.updatedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Upsert by summary text (case-insensitive). New observations
    /// bump the confidence; existing entries get a refreshed updatedAt
    /// and confidence is averaged in. Returns the persisted note.
    @discardableResult
    func record(
        forUser userRemoteID: String,
        summary: String,
        kind: CoachMemoryKind,
        confidence: Double = 0.5,
        now: Date = Date()
    ) throws -> CoachMemoryNote {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw MemoryStoreError.emptySummary }
        let context = ModelContext(container)
        let lowered = trimmed.lowercased()
        let descriptor = FetchDescriptor<CoachMemoryNote>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        if let match = existing.first(where: { $0.summary.lowercased() == lowered }) {
            match.kind = kind
            match.confidence = max(0, min(1, (match.confidence + confidence) / 2))
            match.updatedAt = now
            try context.save()
            return match
        }
        let fresh = CoachMemoryNote(
            userRemoteID: userRemoteID,
            summary: trimmed,
            kind: kind,
            confidence: confidence,
            createdAt: now
        )
        context.insert(fresh)
        try context.save()
        Logger.persistence.notice(
            "CoachMemory recorded \(kind.rawValue, privacy: .public)"
        )
        return fresh
    }

    /// Removes a single note by id. Idempotent — missing rows are a
    /// no-op.
    func delete(noteID: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachMemoryNote>(
            predicate: #Predicate { $0.id == noteID }
        )
        if let row = try context.fetch(descriptor).first {
            context.delete(row)
            try context.save()
        }
    }

    enum MemoryStoreError: Error, Equatable {
        case emptySummary
    }
}
