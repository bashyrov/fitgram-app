import SwiftUI
import WidgetKit

/// Medium/large Home Screen widget showing today's most recent meals.
/// Medium shows up to 3 rows; large shows up to 6 + a "Pozostało"
/// footer line with `goal - consumed` kcal.
struct TodayMealsWidget: Widget {
    let kind: String = "MealgramTodayMealsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayMealsProvider()) { entry in
            TodayMealsWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(WL("Dzisiejsze posiłki"))
        .description(WL("Lista ostatnich posiłków z kaloriami."))
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct TodayMealsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct TodayMealsProvider: TimelineProvider {
    func placeholder(in context: Context) -> TodayMealsEntry {
        TodayMealsEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayMealsEntry) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .preview
        completion(TodayMealsEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayMealsEntry>) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .preview
        let entry = TodayMealsEntry(date: Date(), snapshot: snap)
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct TodayMealsWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TodayMealsEntry

    var body: some View {
        switch family {
        case .systemLarge:
            content(rowLimit: 6, showFooter: true)
        default:
            content(rowLimit: 3, showFooter: false)
        }
    }

    private func content(rowLimit: Int, showFooter: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(WL("Dziś"))
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                if entry.snapshot.calorieGoalKcal > 0 {
                    Text("\(entry.snapshot.caloriesConsumedKcal) kcal")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color("BrandPrimary"))
                }
            }

            if entry.snapshot.recentMeals.isEmpty {
                emptyState
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(entry.snapshot.recentMeals.prefix(rowLimit).enumerated()), id: \.offset) { _, meal in
                        MealRowView(name: meal.name, kcal: meal.kcal)
                    }
                }
            }

            if showFooter {
                Spacer(minLength: 0)
                footer
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(WL("Brak posiłków"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(WL("Stuknij, żeby dodać pierwszy."))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack {
            Text(WL("Pozostało"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(entry.snapshot.caloriesRemainingKcal) kcal")
                .font(.caption.weight(.heavy))
                .foregroundStyle(Color("BrandAccent"))
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(height: 0.5)
        }
    }
}

private struct MealRowView: View {
    let name: String
    let kcal: Int

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color("BrandPrimary"))
                .frame(width: 5, height: 5)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text("\(kcal) kcal")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}

#Preview(as: .systemMedium) {
    TodayMealsWidget()
} timeline: {
    TodayMealsEntry(date: Date(), snapshot: .preview)
}

#Preview(as: .systemLarge) {
    TodayMealsWidget()
} timeline: {
    TodayMealsEntry(date: Date(), snapshot: .preview)
}
