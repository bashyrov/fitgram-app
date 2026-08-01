import SwiftUI
import WidgetKit

/// Small Home Screen widget showing today's water intake. Big "drunk /
/// goal ml" readout with a progress arc behind it.
struct WaterWidget: Widget {
    let kind: String = "MealgramWaterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WaterProvider()) { entry in
            WaterWidgetEntryView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(WL("Woda"))
        .description(WL("Pokaż, ile wody wypito i ile zostało do celu."))
        .supportedFamilies([.systemSmall])
    }
}

struct WaterEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct WaterProvider: TimelineProvider {
    func placeholder(in context: Context) -> WaterEntry {
        WaterEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WaterEntry) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .preview
        completion(WaterEntry(date: Date(), snapshot: snap))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WaterEntry>) -> Void) {
        let snap = WidgetSnapshotStore.shared.load() ?? .preview
        let entry = WaterEntry(date: Date(), snapshot: snap)
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct WaterWidgetEntryView: View {
    let entry: WaterEntry

    var body: some View {
        ZStack {
            arcBackground
            arcForeground(progress: entry.snapshot.waterProgress)
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Text(verbatim: "💧")
                        .font(.title3)
                    Text("\(entry.snapshot.waterMl)")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                }
                if entry.snapshot.waterGoalMl > 0 {
                    Text("/ \(entry.snapshot.waterGoalMl) ml")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                } else {
                    Text("ml")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Text(WL("Woda"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var arcBackground: some View {
        Circle()
            .trim(from: 0.15, to: 0.85)
            .stroke(Color.secondary.opacity(0.18), style: StrokeStyle(lineWidth: 9, lineCap: .round))
            .rotationEffect(.degrees(90))
            .padding(6)
    }

    private func arcForeground(progress: Double) -> some View {
        let span = 0.70
        let trimEnd = 0.15 + span * max(0.001, progress)
        return Circle()
            .trim(from: 0.15, to: trimEnd)
            .stroke(
                Color("BrandPrimary"),
                style: StrokeStyle(lineWidth: 9, lineCap: .round)
            )
            .rotationEffect(.degrees(90))
            .padding(6)
    }
}

#Preview(as: .systemSmall) {
    WaterWidget()
} timeline: {
    WaterEntry(date: Date(), snapshot: .preview)
}
