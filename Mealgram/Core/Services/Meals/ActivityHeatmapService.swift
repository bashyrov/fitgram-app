import Foundation
import SwiftData

/// 90-day "did the user log anything that day" grid. One bin per
/// calendar day with the total calorie count — the view bucketises that
/// into 4 intensity tiers. Pure read service; no writes.
@MainActor
final class ActivityHeatmapService {
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

    /// Returns 90 contiguous days ending at today (newest last). Empty
    /// days are filled with `Cell(date:, kcal: 0)` so the view doesn't
    /// have to gap-fill.
    func snapshot(days: Int = 90) -> ActivityHeatmap.Snapshot {
        let endOfToday = calendar.startOfDay(for: now())
        guard let windowStart = calendar.date(byAdding: .day, value: -(days - 1), to: endOfToday) else {
            return ActivityHeatmap.Snapshot(cells: [], generatedAt: now())
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= windowStart }
        )
        let entries = (try? context.fetch(descriptor)) ?? []
        var byDay: [Date: Double] = [:]
        for entry in entries {
            let key = calendar.startOfDay(for: entry.consumedAt)
            byDay[key, default: 0] += entry.totalCaloriesKcal
        }
        var cells: [ActivityHeatmap.Cell] = []
        for offset in 0..<days {
            guard let day = calendar.date(byAdding: .day, value: offset, to: windowStart) else { continue }
            let key = calendar.startOfDay(for: day)
            cells.append(ActivityHeatmap.Cell(date: key, totalKcal: byDay[key] ?? 0))
        }
        return ActivityHeatmap.Snapshot(cells: cells, generatedAt: now())
    }
}

enum ActivityHeatmap {
    struct Cell: Equatable, Sendable, Identifiable {
        let date: Date
        let totalKcal: Double
        var id: Date { date }

        /// 0…3 — view consults this to pick the colour token. Cutoffs are
        /// deliberately gentle so even one item earns the lightest shade.
        var intensity: Int {
            switch totalKcal {
            case 0: return 0
            case 1..<800: return 1
            case 800..<1600: return 2
            default: return 3
            }
        }
    }

    struct Snapshot: Equatable, Sendable {
        let cells: [Cell]
        let generatedAt: Date

        /// Longest consecutive run of "did the user log anything" days in
        /// the 90-day window. Used by the Profile heatmap caption
        /// ("Najlepszy tydzień: N dni z rzędu"). Pure derived property —
        /// scans the cells once, O(n).
        var longestActiveRun: Int {
            var best = 0
            var current = 0
            for cell in cells {
                if cell.totalKcal > 0 {
                    current += 1
                    if current > best { best = current }
                } else {
                    current = 0
                }
            }
            return best
        }
    }
}
