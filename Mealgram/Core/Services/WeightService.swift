import Foundation
import OSLog
import SwiftData

/// CRUD + read summaries for `WeightEntry`. Pulls one user at a time;
/// caching belongs to the view-model layer.
@MainActor
final class WeightService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func entries(for userRemoteID: String) throws -> [WeightEntry] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID },
            sortBy: [SortDescriptor(\WeightEntry.recordedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func log(
        _ weightKg: Double, for userRemoteID: String, note: String? = nil, at date: Date = Date()
    ) throws -> WeightEntry {
        let context = ModelContext(container)
        let entry = WeightEntry(
            userRemoteID: userRemoteID,
            recordedAt: date,
            weightKg: weightKg,
            note: note
        )
        context.insert(entry)
        // Mirror the latest weight onto the user profile so calorie-goal
        // math has somewhere current to read from.
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        if let user = try context.fetch(descriptor).first {
            user.weightKg = weightKg
            user.updatedAt = Date()
        }
        try context.save()
        Logger.persistence.notice("Logged weight \(weightKg, format: .fixed(precision: 1)) kg")
        return entry
    }

    /// Edits an existing weight entry in place. Re-fetches by id so the
    /// caller's @Model instance (potentially in a different context) is
    /// not the one being mutated.
    func update(_ entry: WeightEntry, weightKg: Double, note: String?) throws {
        let context = ModelContext(container)
        let entryID = entry.id
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        guard let stored = try context.fetch(descriptor).first else { return }
        stored.weightKg = weightKg
        stored.note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (stored.note ?? "").isEmpty { stored.note = nil }
        try context.save()
    }

    func delete(_ entry: WeightEntry) throws {
        let context = ModelContext(container)
        let entryID = entry.id
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        if let stored = try context.fetch(descriptor).first {
            context.delete(stored)
            try context.save()
        }
    }

    /// Returns the most recent and the oldest entry within the last 30
    /// days so the UI can show a delta, plus the 7-day rolling average.
    func summary(for userRemoteID: String) throws -> Summary? {
        let entries = try entries(for: userRemoteID)
        guard let latest = entries.first else { return nil }
        let now = Date()
        let calendar = Calendar.current
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let monthSlice = entries.filter { $0.recordedAt >= monthAgo }
        let comparable = monthSlice.last ?? latest
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let weekSlice = entries.filter { $0.recordedAt >= weekAgo }
        let sevenDayAverage: Double?
        if weekSlice.isEmpty {
            sevenDayAverage = nil
        } else {
            let total = weekSlice.reduce(0.0) { $0 + $1.weightKg }
            sevenDayAverage = total / Double(weekSlice.count)
        }
        return Summary(
            latest: latest,
            thirtyDayDelta: latest.weightKg - comparable.weightKg,
            sevenDayAverageKg: sevenDayAverage,
            entries: entries
        )
    }

    struct Summary: Sendable {
        let latest: WeightEntry
        let thirtyDayDelta: Double
        let sevenDayAverageKg: Double?
        let entries: [WeightEntry]
    }
}
