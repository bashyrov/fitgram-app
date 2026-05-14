import Foundation
import OSLog
import SwiftData

/// Read + write model behind the Goal Tracking feature. Wraps
/// `WeightService` for persistence so every goal weigh-in shows up in
/// "Waga i trend" too. All maths live here — pure functions on the
/// summary type so the views stay declarative.
@MainActor
final class GoalTrackingService {
    private let weightService: WeightService
    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        weightService: WeightService,
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.weightService = weightService
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    /// Captures the user-facing state the GoalTrackingView needs in a
    /// single sendable struct. Pure values — no SwiftData @Model leaks
    /// out, so the view layer can hold this snapshot across refreshes
    /// without worrying about context isolation.
    struct Snapshot: Sendable, Equatable {
        struct Point: Sendable, Equatable, Identifiable {
            let id: UUID
            let date: Date
            let weightKg: Double
        }

        let goalKind: GoalKind
        let startWeightKg: Double
        let currentWeightKg: Double
        let targetWeightKg: Double
        let startDate: Date
        let estimatedEndDate: Date?
        let daysElapsed: Int
        /// Days between start and estimatedEndDate (inclusive of start).
        /// Nil when estimatedEndDate is missing.
        let totalDays: Int?
        let entries: [Point]
        let isGoalReached: Bool

        /// 0.0 → 1.0 progress towards target. Distance covered ÷ distance
        /// to cover. Clamped to [0, 1]. For lose: weight going down is
        /// progress; for gain: weight going up.
        var progress: Double {
            let distanceToCover = abs(startWeightKg - targetWeightKg)
            guard distanceToCover > 0.05 else { return 1 }
            let distanceCovered: Double
            switch goalKind {
            case .lose:
                distanceCovered = max(0, startWeightKg - currentWeightKg)
            case .gain:
                distanceCovered = max(0, currentWeightKg - startWeightKg)
            default:
                distanceCovered = 0
            }
            let ratio = distanceCovered / distanceToCover
            return min(1.0, max(0.0, ratio))
        }

        /// Last 14 days of weigh-ins for the sparkline on the Today
        /// card. Sorted oldest → newest.
        var last14Days: [Point] {
            let calendar = Calendar.current
            guard let cutoff = calendar.date(byAdding: .day, value: -14, to: Date()) else {
                return entries
            }
            return entries.filter { $0.date >= cutoff }
        }
    }

    /// Returns nil when the user lacks a structured weight goal. The
    /// view layer can therefore avoid rendering the card / screen
    /// entirely.
    func snapshot(for userRemoteID: String) -> Snapshot? {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        guard let user = try? context.fetch(descriptor).first else { return nil }
        guard user.goalKind == .lose || user.goalKind == .gain else { return nil }
        guard let startDate = user.goalStartDate,
            let target = user.goalTargetWeightKg
        else { return nil }

        let allEntries = (try? weightService.entries(for: userRemoteID)) ?? []
        let startOfStart = calendar.startOfDay(for: startDate)
        let goalEntries = allEntries.filter { $0.recordedAt >= startOfStart }

        let startWeight: Double
        if let earliest = goalEntries.min(by: { $0.recordedAt < $1.recordedAt }) {
            startWeight = earliest.weightKg
        } else {
            startWeight = user.weightKg ?? target
        }

        let currentWeight: Double
        if let latest = goalEntries.max(by: { $0.recordedAt < $1.recordedAt }) {
            currentWeight = latest.weightKg
        } else {
            currentWeight = user.weightKg ?? startWeight
        }

        let nowDate = now()
        let dayStartNow = calendar.startOfDay(for: nowDate)
        let elapsed = max(
            0, calendar.dateComponents([.day], from: startOfStart, to: dayStartNow).day ?? 0
        )
        let totalDays: Int? = user.goalEstimatedEndDate.flatMap { end in
            let endDay = calendar.startOfDay(for: end)
            return calendar.dateComponents([.day], from: startOfStart, to: endDay).day
        }

        let isReached: Bool
        switch user.goalKind {
        case .lose: isReached = currentWeight <= target
        case .gain: isReached = currentWeight >= target
        default: isReached = false
        }

        let points = goalEntries
            .sorted(by: { $0.recordedAt < $1.recordedAt })
            .map { entry in
                Snapshot.Point(
                    id: entry.id,
                    date: entry.recordedAt,
                    weightKg: entry.weightKg
                )
            }

        return Snapshot(
            goalKind: user.goalKind,
            startWeightKg: startWeight,
            currentWeightKg: currentWeight,
            targetWeightKg: target,
            startDate: startOfStart,
            estimatedEndDate: user.goalEstimatedEndDate,
            daysElapsed: elapsed,
            totalDays: totalDays,
            entries: points,
            isGoalReached: isReached
        )
    }

    /// Records a goal weigh-in for the user. One row per calendar day —
    /// re-tapping today's date updates the existing row instead of
    /// inserting a duplicate. Mirrors into the WeightService timeline so
    /// the "Waga i trend" tab stays in sync.
    @discardableResult
    func logTodayWeight(_ weightKg: Double, for userRemoteID: String) -> WeightEntry? {
        do {
            return try weightService.logOrUpdateForDay(
                weightKg,
                for: userRemoteID,
                note: nil,
                on: now(),
                source: .goalTracker,
                calendar: calendar
            )
        } catch {
            Logger.persistence.error(
                "Failed to log goal weigh-in: \(String(describing: error))"
            )
            return nil
        }
    }
}
