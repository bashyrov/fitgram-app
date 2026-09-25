import Charts
import SwiftUI

struct GoalTrendChart: View {
    let snapshot: GoalTrackingService.Snapshot

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMM"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            header
            metricStrip
            if snapshot.entries.count >= 2 {
                chartBody
            } else {
                emptyState
            }
        }
        .padding(Tokens.Space.lg)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(backgroundGradient)
        }
        .shadow(color: Tokens.Palette.primary.opacity(0.12), radius: 22, x: 0, y: 12)
    }

    private var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Tokens.Palette.surface.opacity(0.92),
                Tokens.Palette.primarySoft.opacity(0.72),
                Tokens.Palette.surface.opacity(0.84),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Trend")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(rangeLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            Text(goalDirectionLabel)
                .font(Tokens.Font.caption.weight(.bold))
                .foregroundStyle(Tokens.Palette.primary)
                .padding(.horizontal, Tokens.Space.sm)
                .frame(height: 28)
                .background(Capsule().fill(Tokens.Palette.surface.opacity(0.7)))
        }
    }

    private var metricStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            metric(
                title: "Do celu",
                value: String(format: "%.1f kg", remainingKg),
                tint: Tokens.Palette.primary
            )
            metric(
                title: "Zmiana",
                value: signedKg(weightDelta),
                tint: weightDelta == 0 ? Tokens.Palette.inkMuted : Tokens.Palette.accent
            )
            metric(
                title: "Postęp",
                value: "\(Int((snapshot.progress * 100).rounded()))%",
                tint: Tokens.Palette.success
            )
        }
    }

    private func metric(title: LocalizedStringKey, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(Tokens.Font.caption2.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(value)
                .font(Tokens.Font.footnote.weight(.heavy))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, Tokens.Space.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.66))
        )
    }

    private var chartBody: some View {
        let yDomain = chartYDomain
        return Chart {
            ForEach(snapshot.entries) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    yStart: .value("Floor", yDomain.lowerBound),
                    yEnd: .value("Weight", point.weightKg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(areaGradient)
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weightKg)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3.2, lineCap: .round, lineJoin: .round))
                .foregroundStyle(lineGradient)
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weightKg)
                )
                .symbolSize(isLatest(point) ? 74 : 30)
                .foregroundStyle(isLatest(point) ? Tokens.Palette.accent : Tokens.Palette.primary)
            }
            RuleMark(y: .value("Target", snapshot.targetWeightKg))
                .lineStyle(StrokeStyle(lineWidth: 1.4, dash: [5, 5]))
                .foregroundStyle(Tokens.Palette.warning.opacity(0.85))
                .annotation(position: .top, alignment: .trailing, spacing: 6) {
                    targetChip
                }
            if let estimated = snapshot.estimatedEndDate {
                RuleMark(x: .value("End", estimated))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundStyle(Tokens.Palette.accent.opacity(0.85))
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .chartPlotStyle { plot in
            plot
                .background(Tokens.Palette.surface.opacity(0.34))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .frame(height: 250)
        .padding(.top, Tokens.Space.xs)
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Tokens.Palette.primary.opacity(0.28),
                Tokens.Palette.primary.opacity(0.04),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var lineGradient: LinearGradient {
        LinearGradient(
            colors: [Tokens.Palette.primary, Tokens.Palette.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var targetChip: some View {
        Text(String(format: "%.1f kg", snapshot.targetWeightKg))
            .font(Tokens.Font.caption2.weight(.bold))
            .foregroundStyle(Tokens.Palette.warning)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Tokens.Palette.surface.opacity(0.86)))
    }

    private var xAxisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisValueLabel(format: .dateTime.day().month())
                .font(Tokens.Font.caption2)
                .foregroundStyle(Tokens.Palette.inkMuted)
            AxisGridLine().foregroundStyle(Tokens.Palette.separator.opacity(0.55))
        }
    }

    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { _ in
            AxisGridLine().foregroundStyle(Tokens.Palette.separator.opacity(0.55))
            AxisValueLabel()
                .font(Tokens.Font.caption2)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
    }

    private var emptyState: some View {
        Text("Add one more entry to see a trend.")
            .font(Tokens.Font.footnote)
            .foregroundStyle(Tokens.Palette.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Tokens.Space.lg)
    }

    private var chartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let earliestEntry = snapshot.entries.min(by: { $0.date < $1.date })?.date
        let latestEntry = snapshot.entries.max(by: { $0.date < $1.date })?.date
        let lower =
            earliestEntry.map { calendar.date(byAdding: .hour, value: -12, to: $0) ?? $0 }
            ?? snapshot.startDate
        let upperCandidates: [Date] = [
            latestEntry.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) },
            snapshot.estimatedEndDate,
            calendar.date(byAdding: .day, value: 1, to: Date()),
        ].compactMap { $0 }
        let upper = upperCandidates.max() ?? Date()
        return lower...max(upper, calendar.date(byAdding: .day, value: 1, to: lower) ?? upper)
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights =
            snapshot.entries.map(\.weightKg) + [
                snapshot.startWeightKg,
                snapshot.currentWeightKg,
                snapshot.targetWeightKg,
            ]
        let minWeight = weights.min() ?? snapshot.targetWeightKg
        let maxWeight = weights.max() ?? snapshot.currentWeightKg
        let padding = max(0.6, (maxWeight - minWeight) * 0.22)
        return (minWeight - padding)...(maxWeight + padding)
    }

    private var remainingKg: Double {
        abs(snapshot.currentWeightKg - snapshot.targetWeightKg)
    }

    private var weightDelta: Double {
        snapshot.currentWeightKg - snapshot.startWeightKg
    }

    private var rangeLabel: String {
        let start = Self.dayFormatter.string(from: snapshot.startDate)
        let end = Self.dayFormatter.string(from: Date())
        return "\(start) -> \(end)"
    }

    private var goalDirectionLabel: String {
        switch snapshot.goalKind {
        case .lose:
            return L("Redukcja")
        case .gain:
            return L("Masa")
        default:
            return L("Cel")
        }
    }

    private func signedKg(_ value: Double) -> String {
        if abs(value) < 0.05 { return "0.0 kg" }
        return String(format: "%+.1f kg", value)
    }

    private func isLatest(_ point: GoalTrackingService.WeighInPoint) -> Bool {
        point.id == snapshot.entries.last?.id
    }
}
