import SwiftUI
import WidgetKit

/// Home Screen widget showing today's calorie ring + macro progress.
/// Small family is a tight ring with kcal in the center and three macro
/// dots underneath; medium puts the ring on the left and full P/C/F
/// progress bars on the right.
struct CalorieRingWidget: Widget {
    let kind: String = "MealgramCalorieRingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieRingProvider()) { entry in
            CalorieRingWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(String(localized: "Kalorie i makro"))
        .description(String(localized: "Pierścień kalorii i pasek makro na dziś."))
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct CalorieRingEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct CalorieRingProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieRingEntry {
        CalorieRingEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieRingEntry) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .placeholder
        completion(CalorieRingEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieRingEntry>) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .placeholder
        let entry = CalorieRingEntry(date: Date(), snapshot: snap)
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct CalorieRingWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalorieRingEntry

    var body: some View {
        switch family {
        case .systemMedium:
            mediumView
        default:
            smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            ZStack {
                ringBackground
                ringForeground(progress: entry.snapshot.calorieProgress)
                VStack(spacing: 0) {
                    Text("\(entry.snapshot.caloriesConsumedKcal)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                    Text("kcal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 84, height: 84)

            HStack(spacing: 10) {
                MacroDot(label: "B", progress: entry.snapshot.proteinProgress, color: Color("BrandPrimary"))
                MacroDot(label: "W", progress: entry.snapshot.carbsProgress, color: Color("BrandAccent"))
                MacroDot(label: "T", progress: entry.snapshot.fatProgress, color: .yellow)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            ZStack {
                ringBackground
                ringForeground(progress: entry.snapshot.calorieProgress)
                VStack(spacing: 0) {
                    Text("\(entry.snapshot.caloriesConsumedKcal)")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                    if entry.snapshot.calorieGoalKcal > 0 {
                        Text("/ \(entry.snapshot.calorieGoalKcal)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 100, height: 100)

            VStack(alignment: .leading, spacing: 8) {
                MacroBar(
                    name: String(localized: "Białko"),
                    consumed: entry.snapshot.proteinConsumedGrams,
                    goal: entry.snapshot.proteinGoalGrams,
                    progress: entry.snapshot.proteinProgress,
                    color: Color("BrandPrimary")
                )
                MacroBar(
                    name: String(localized: "Węgle"),
                    consumed: entry.snapshot.carbsConsumedGrams,
                    goal: entry.snapshot.carbsGoalGrams,
                    progress: entry.snapshot.carbsProgress,
                    color: Color("BrandAccent")
                )
                MacroBar(
                    name: String(localized: "Tłuszcz"),
                    consumed: entry.snapshot.fatConsumedGrams,
                    goal: entry.snapshot.fatGoalGrams,
                    progress: entry.snapshot.fatProgress,
                    color: .yellow
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var ringBackground: some View {
        Circle()
            .stroke(Color.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 10, lineCap: .round))
    }

    private func ringForeground(progress: Double) -> some View {
        Circle()
            .trim(from: 0, to: max(0.001, progress))
            .stroke(
                Color("BrandPrimary"),
                style: StrokeStyle(lineWidth: 10, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}

private struct MacroDot: View {
    let label: String
    let progress: Double
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.18), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(0.001, progress))
                    .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 18, height: 18)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MacroBar: View {
    let name: String
    let consumed: Int
    let goal: Int
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if goal > 0 {
                    Text("\(consumed)/\(goal) g")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                } else {
                    Text("\(consumed) g")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.primary)
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.18))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 6)
        }
    }
}

#Preview(as: .systemSmall) {
    CalorieRingWidget()
} timeline: {
    CalorieRingEntry(date: Date(), snapshot: .preview)
}

#Preview(as: .systemMedium) {
    CalorieRingWidget()
} timeline: {
    CalorieRingEntry(date: Date(), snapshot: .preview)
}
