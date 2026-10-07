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

    /// Mockup GoalTracking trend card: "TREND" label, 130 pt chart with a strong weight line,
    /// dashed muted goal line and a dashed projection to the estimated end date.
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if snapshot.entries.count >= 2 {
                chartBody
            } else {
                emptyState
            }
            metricStrip
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MonoLabel(text: L("Trend") + " · " + goalDirectionLabel)
            Spacer(minLength: 8)
            Text(rangeLabel)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineLimit(1)
        }
    }

    /// Remaining distance + change since start (progress % lives in the hero above).
    private var metricStrip: some View {
        HStack(alignment: .top, spacing: 10) {
            MonoStat(label: L("Do celu"), value: String(format: "%.1f", remainingKg), unit: "kg", size: 18)
            MonoStat(label: L("Zmiana"), value: signedKg(weightDelta), unit: "kg", size: 18)
        }
        .padding(.top, 12)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.line).frame(height: 1)
        }
    }

    private var chartBody: some View {
        let yDomain = chartYDomain
        return Chart {
            RuleMark(y: .value("Target", snapshot.targetWeightKg))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Tokens.Mono.muted)
            ForEach(snapshot.entries) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.weightKg),
                    series: .value("Series", "weight")
                )
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Tokens.Mono.strong)
            }
            if let projection = projectionSegment {
                LineMark(
                    x: .value("Date", projection.start.date),
                    y: .value("Weight", projection.start.weightKg),
                    series: .value("Series", "projection")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                .foregroundStyle(Tokens.Mono.muted)
                LineMark(
                    x: .value("Date", projection.end),
                    y: .value("Weight", snapshot.targetWeightKg),
                    series: .value("Series", "projection")
                )
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 5]))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .chartXScale(domain: chartXDomain)
        .chartYScale(domain: yDomain)
        .chartXAxis { xAxisMarks }
        .chartYAxis { yAxisMarks }
        .frame(height: 130)
    }

    /// Latest weigh-in → (estimated end date, target), only while the goal is still open.
    private var projectionSegment: (start: GoalTrackingService.WeighInPoint, end: Date)? {
        guard !snapshot.isGoalReached,
            let estimated = snapshot.estimatedEndDate,
            let last = snapshot.entries.last,
            estimated > last.date
        else { return nil }
        return (start: last, end: estimated)
    }

    private var xAxisMarks: some AxisContent {
        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
            AxisValueLabel(format: .dateTime.day().month())
                .font(Tokens.Font.manrope(10, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
        }
    }

    private var yAxisMarks: some AxisContent {
        AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
            AxisGridLine().foregroundStyle(Tokens.Mono.line)
            AxisValueLabel()
                .font(Tokens.Font.manrope(10, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
        }
    }

    private var emptyState: some View {
        Text("Add one more entry to see a trend.")
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
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
        if abs(value) < 0.05 { return "0.0" }
        return (value > 0 ? "+" : "−") + String(format: "%.1f", abs(value))
    }

    private func isLatest(_ point: GoalTrackingService.WeighInPoint) -> Bool {
        point.id == snapshot.entries.last?.id
    }
}
