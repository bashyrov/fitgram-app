import Foundation
import OSLog
import SwiftData

/// Persists Ola's weekly debriefs so the user can scroll back through
/// past weeks. Idempotent on the (user, weekStart) key — calling
/// `record` twice in the same week updates the existing row rather than
/// duplicating.
@MainActor
final class CoachInsightLogStore {
    /// Codable mirror of `CoachInsight` for the JSON column. Keeps the
    /// stored format independent of the live struct so rule engine
    /// renames don't corrupt the history.
    struct StoredInsight: Codable, Equatable {
        let tone: String
        let headline: String
        let body: String
        let actionTitle: String?
        let actionKind: String?
    }

    struct StoredStat: Codable, Equatable {
        let kind: String
        let value: String
        let caption: String
    }

    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        calendar: Calendar = CoachInsightLogStore.mondayStartCalendar(),
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    static func mondayStartCalendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        return calendar
    }

    func record(_ debrief: WeeklyDebrief, for userRemoteID: String) {
        let weekStart = currentWeekStart()
        let insights = debrief.insights.map { insight in
            StoredInsight(
                tone: insight.tone.rawValue,
                headline: insight.headline,
                body: insight.body,
                actionTitle: insight.actionTitle,
                actionKind: insight.actionKind?.rawValue
            )
        }
        let stats = debrief.stats.map {
            StoredStat(kind: $0.kind.rawValue, value: $0.value, caption: $0.caption)
        }
        guard let insightsJSON = encode(insights), let statsJSON = encode(stats) else { return }

        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachInsightLog>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.weekStartAt == weekStart
            }
        )
        do {
            if let existing = try context.fetch(descriptor).first {
                existing.headline = debrief.headline
                existing.insightsJSON = insightsJSON
                existing.statsJSON = statsJSON
                existing.generatedAt = now()
            } else {
                let row = CoachInsightLog(
                    userRemoteID: userRemoteID,
                    weekStartAt: weekStart,
                    generatedAt: now(),
                    headline: debrief.headline,
                    insightsJSON: insightsJSON,
                    statsJSON: statsJSON
                )
                context.insert(row)
            }
            try context.save()
        } catch {
            Logger.persistence.error("CoachInsightLog record failed: \(String(describing: error))")
        }
    }

    /// Records the user's thumbs up/down for the current week. Idempotent
    /// — flipping the bit just overwrites; nil means "not yet asked".
    func recordFeedback(helpful: Bool, for userRemoteID: String) {
        let weekStart = currentWeekStart()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachInsightLog>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.weekStartAt == weekStart
            }
        )
        do {
            guard let log = try context.fetch(descriptor).first else { return }
            log.helpful = helpful
            try context.save()
        } catch {
            Logger.persistence.error("CoachInsightLog feedback save failed: \(String(describing: error))")
        }
    }

    /// Returns the helpful flag for the current week, or nil if not asked
    /// yet.
    func feedback(for userRemoteID: String) -> Bool? {
        let weekStart = currentWeekStart()
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<CoachInsightLog>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.weekStartAt == weekStart
            }
        )
        return (try? context.fetch(descriptor).first)?.helpful
    }

    func recent(for userRemoteID: String, limit: Int = 12) -> [CoachInsightLog] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<CoachInsightLog>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID },
            sortBy: [SortDescriptor(\CoachInsightLog.weekStartAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return (try? context.fetch(descriptor)) ?? []
    }

    func decodeInsights(_ json: String) -> [StoredInsight] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StoredInsight].self, from: data)) ?? []
    }

    func decodeStats(_ json: String) -> [StoredStat] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StoredStat].self, from: data)) ?? []
    }

    // MARK: - Helpers

    private func currentWeekStart() -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now())
        return calendar.date(from: components) ?? now()
    }

    private func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
