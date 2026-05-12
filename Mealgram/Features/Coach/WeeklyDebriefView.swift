import SwiftUI

/// "Co u Ciebie" — the once-a-week summary Ola delivers. Pulled lazily
/// from `CoachService` when the user opens the sheet; pure read-model.
struct WeeklyDebriefView: View {
    let debrief: WeeklyDebrief
    let onDismiss: () -> Void
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenHistory: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        statsGrid
                        insightsSection
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Co u Ciebie"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onOpenHistory {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onOpenHistory()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(Text("Historia"))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Card(background: Tokens.Palette.primarySoft) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primary)
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ola podsumowuje")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(debrief.headline)
                        .font(Tokens.Font.title)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(rangeCaption)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var rangeCaption: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "d MMMM"
        let calendar = Calendar.current
        let to = debrief.generatedAt
        let from = calendar.date(byAdding: .day, value: -6, to: to) ?? to
        return "\(formatter.string(from: from)) – \(formatter.string(from: to))"
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Twoje statystyki")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                    ],
                    spacing: Tokens.Space.md
                ) {
                    ForEach(debrief.stats) { stat in
                        statTile(stat)
                    }
                }
            }
        }
    }

    private func statTile(_ stat: WeeklyDebrief.Stat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(stat.value)
                .font(Tokens.Font.counter)
                .foregroundStyle(Tokens.Palette.primary)
            Text(stat.caption)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.primarySoft.opacity(0.5))
        )
    }

    // MARK: - Insights section

    @ViewBuilder
    private var insightsSection: some View {
        if debrief.insights.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Wgląd Oli")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(debrief.insights) { insight in
                    AIInsightCard(insight: insight, onAction: onCoachAction)
                }
            }
        }
    }
}
