import SwiftUI
import WidgetKit

/// Minimal Home Screen widget for Mealgram. Reads the most recent
/// snapshot the main app wrote to a shared App Group UserDefaults
/// (see `WidgetSnapshot`). Falls back to a friendly "Otwórz Mealgram"
/// state when the app hasn't written one yet (fresh install, simulator
/// without App Group entitlement, etc.).
struct StreakWidget: Widget {
    let kind: String = "MealgramStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakProvider()) { entry in
            StreakWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(WL("Your streak"))
        .description(WL("Show your meal streak and calorie progress."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StreakEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct StreakProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakEntry {
        StreakEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StreakEntry) -> Void) {
        completion(StreakEntry(date: Date(), snapshot: WidgetSnapshotStore.shared.load() ?? .preview))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakEntry>) -> Void) {
        let entry = StreakEntry(date: Date(), snapshot: WidgetSnapshotStore.shared.load() ?? .preview)
        // Refresh every 30 min — the app also pushes via WidgetCenter
        // after every meal save for faster feedback.
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct StreakWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: StreakEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text("\(entry.snapshot.streakLength)")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Text(entry.snapshot.streakLength == 1 ? WL("day in a row") : WL("days in a row"))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if entry.snapshot.calorieGoalKcal > 0 {
                Text("\(entry.snapshot.caloriesRemainingKcal) kcal")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("do celu")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            smallView
            Spacer()
            VStack(alignment: .leading, spacing: 6) {
                Text("Mealgram")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if entry.snapshot.lastMealName.isEmpty {
                    Text(WL("Tap to add your first meal."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    Text("Ostatnio")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.snapshot.lastMealName)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
