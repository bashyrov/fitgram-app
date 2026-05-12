import Foundation
import SwiftData

/// Read/write for the daily water log. Daily goal defaults to 2000 ml
/// (8 standard 250 ml glasses) — exposed as a constant so any future
/// per-user override stays a one-line change.
@MainActor
final class WaterService {
    static let defaultDailyGoalMilliliters = 2000
    static let glassMilliliters = 250

    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    @discardableResult
    func log(forUser userRemoteID: String, milliliters: Int) throws -> WaterEntry {
        let context = ModelContext(container)
        let entry = WaterEntry(
            userRemoteID: userRemoteID,
            recordedAt: now(),
            milliliters: milliliters
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func totalToday(for userRemoteID: String) -> Int {
        let dayStart = calendar.startOfDay(for: now())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return 0 }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID
                    && $0.recordedAt >= dayStart
                    && $0.recordedAt < dayEnd
            }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        return entries.reduce(0) { $0 + $1.milliliters }
    }

    func todaysEntries(for userRemoteID: String) -> [WaterEntry] {
        let dayStart = calendar.startOfDay(for: now())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return [] }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID
                    && $0.recordedAt >= dayStart
                    && $0.recordedAt < dayEnd
            },
            sortBy: [SortDescriptor(\WaterEntry.recordedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Removes the most recent entry — used by the "ups, pomyłka" tap.
    func undoLast(for userRemoteID: String) throws {
        let entries = todaysEntries(for: userRemoteID)
        guard let latest = entries.first else { return }
        let context = ModelContext(container)
        let entryID = latest.id
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate { $0.id == entryID }
        )
        guard let attached = try context.fetch(descriptor).first else { return }
        context.delete(attached)
        try context.save()
    }
}
