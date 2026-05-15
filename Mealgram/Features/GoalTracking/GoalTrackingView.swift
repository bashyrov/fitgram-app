import Charts
import SwiftUI

/// Full-screen Goal Tracking surface. Big chart + "Wpisz dzisiejszą
/// wagę" CTA. Premium-only — caller is responsible for the gate.
struct GoalTrackingView: View {
    let userRemoteID: String
    @Bindable var state: GoalTrackingState
    let onDismiss: () -> Void

    @State private var isAddPresented = false

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "d MMM"
        return formatter
    }()

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        if let snapshot = state.snapshot {
                            if snapshot.isGoalReached {
                                goalReachedPill
                            }
                            summaryCard(snapshot)
                            chartCard(snapshot)
                            PrimaryButton(
                                title: "Wpisz dzisiejszą wagę",
                                systemImage: "scalemass.fill",
                                isLoading: state.isSaving
                            ) {
                                isAddPresented = true
                            }
                        } else {
                            emptyCard
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Twój cel"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .task { state.refresh(for: userRemoteID) }
            .sheet(isPresented: $isAddPresented) {
                AddGoalWeightSheet(
                    initialWeight: state.snapshot?.currentWeightKg,
                    onCommit: { weight in
                        Task {
                            await state.logTodayWeight(weight, for: userRemoteID)
                            Haptics.success()
                        }
                    },
                    onDismiss: { isAddPresented = false }
                )
            }
        }
    }

    private var goalReachedPill: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.white)
            Text("Cel osiągnięty 🎉")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            Capsule().fill(Tokens.Palette.success)
        )
        .frame(maxWidth: .infinity)
    }

    private func summaryCard(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aktualnie")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text(String(format: "%.1f kg", snapshot.currentWeightKg))
                            .font(Tokens.Font.counter)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Cel")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text(String(format: "%.1f kg", snapshot.targetWeightKg))
                            .font(Tokens.Font.title2)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tokens.Palette.primarySoft)
                        Capsule()
                            .fill(Tokens.Palette.primary)
                            .frame(width: proxy.size.width * CGFloat(snapshot.progress))
                    }
                }
                .frame(height: 10)
                HStack {
                    Text(progressLabel(snapshot))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Text(daysLabel(snapshot))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private func progressLabel(_ snapshot: GoalTrackingService.Snapshot) -> String {
        let percent = Int((snapshot.progress * 100).rounded())
        return String(localized: "Postęp \(percent)%")
    }

    private func daysLabel(_ snapshot: GoalTrackingService.Snapshot) -> String {
        if let total = snapshot.totalDays, total > 0 {
            return String(localized: "Dzień \(snapshot.daysElapsed) z \(total)")
        }
        return String(localized: "Dzień \(snapshot.daysElapsed)")
    }

    private func chartCard(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                chartHeader(snapshot)
                if snapshot.entries.count >= 2 {
                    chartBody(snapshot)
                } else {
                    chartEmptyState
                }
            }
        }
    }

    private func chartHeader(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        HStack {
            Text("Trend")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Text(rangeLabel(snapshot))
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private func chartBody(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        Chart {
            ForEach(snapshot.entries) { point in
                LineMark(
                    x: .value("Data", point.date),
                    y: .value("Waga", point.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Tokens.Palette.primary)
                PointMark(
                    x: .value("Data", point.date),
                    y: .value("Waga", point.weightKg)
                )
                .symbolSize(28)
                .foregroundStyle(Tokens.Palette.primary)
            }
            RuleMark(y: .value("Cel", snapshot.targetWeightKg))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Tokens.Palette.warning)
                .annotation(position: .top, alignment: .trailing) {
                    Text(String(format: "Cel %.1f kg", snapshot.targetWeightKg))
                        .font(Tokens.Font.caption2)
                        .foregroundStyle(Tokens.Palette.warning)
                }
            if let estimated = snapshot.estimatedEndDate {
                RuleMark(x: .value("Koniec", estimated))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                    .foregroundStyle(Tokens.Palette.accent)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Plan")
                            .font(Tokens.Font.caption2)
                            .foregroundStyle(Tokens.Palette.accent)
                    }
            }
        }
        .chartXScale(domain: chartXDomain(snapshot))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.day().month())
                    .font(Tokens.Font.caption2)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                AxisGridLine().foregroundStyle(Tokens.Palette.separator)
            }
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Tokens.Palette.separator)
                AxisValueLabel()
                    .font(Tokens.Font.caption2)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .frame(height: 220)
    }

    /// Adaptive x-axis range. Spans `[earliest entry - 0.5d, latest + 1d]`
    /// so a tiny 2-3 entry log already reads as a chart instead of two
    /// points overlapping at the same x. Always honours the goal start
    /// as the lower floor and includes the projected end if known.
    private func chartXDomain(_ snapshot: GoalTrackingService.Snapshot) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let earliestEntry = snapshot.entries.min(by: { $0.date < $1.date })?.date
        let latestEntry = snapshot.entries.max(by: { $0.date < $1.date })?.date
        let lower = earliestEntry.map { calendar.date(byAdding: .hour, value: -12, to: $0) ?? $0 }
            ?? snapshot.startDate
        let upperCandidates: [Date] = [
            latestEntry.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) },
            snapshot.estimatedEndDate,
            calendar.date(byAdding: .day, value: 1, to: Date()),
        ].compactMap { $0 }
        let upper = upperCandidates.max() ?? Date()
        return lower...max(upper, calendar.date(byAdding: .day, value: 1, to: lower) ?? upper)
    }

    private var chartEmptyState: some View {
        Text("Dodaj jeszcze jeden wpis, żeby zobaczyć trend.")
            .font(Tokens.Font.footnote)
            .foregroundStyle(Tokens.Palette.inkMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Tokens.Space.lg)
    }

    private func rangeLabel(_ snapshot: GoalTrackingService.Snapshot) -> String {
        let start = Self.dayFormatter.string(from: snapshot.startDate)
        let end = Self.dayFormatter.string(from: Date())
        return "\(start) → \(end)"
    }

    private var emptyCard: some View {
        Card {
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "target")
                    .font(.system(size: 36))
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Brak aktywnego celu")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Wybierz cel \"Zrzucić wagę\" lub \"Przybrać na wadze\" w Profilu → Cele, żeby aktywować śledzenie."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
