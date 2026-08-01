import SwiftUI

/// "How you're doing" — the once-a-week summary Ola delivers. Pulled lazily
/// from `CoachService` when the user opens the sheet; pure read-model.
struct WeeklyDebriefView: View {
    let debrief: WeeklyDebrief
    let onDismiss: () -> Void
    var onCoachAction: ((CoachInsight.ActionKind) -> Void)?
    var onOpenHistory: (() -> Void)?
    var existingFeedback: Bool?
    var onFeedback: ((Bool) -> Void)?

    @State private var localFeedback: Bool?

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        statsGrid
                        insightsSection
                        if onFeedback != nil {
                            feedbackRow
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("How you're doing"))
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
                    Button("Close", action: onDismiss)
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
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
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

    // MARK: - Feedback

    private var resolvedFeedback: Bool? { localFeedback ?? existingFeedback }

    @ViewBuilder
    private var feedbackRow: some View {
        if let value = resolvedFeedback {
            Card(background: Tokens.Palette.primarySoft.opacity(0.5)) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: value ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(
                        value
                            ? LocalizedStringKey("Thanks for the feedback!")
                            : LocalizedStringKey("Zanotowane — postaramy się bardziej dopasować.")
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.ink)
                    Spacer(minLength: 0)
                }
            }
        } else {
            Card {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text("Helpful?")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    HStack(spacing: Tokens.Space.md) {
                        feedbackButton(value: true, symbol: "hand.thumbsup", label: "Yes")
                        feedbackButton(value: false, symbol: "hand.thumbsdown", label: "No")
                    }
                }
            }
        }
    }

    private func feedbackButton(value: Bool, symbol: String, label: LocalizedStringKey) -> some View {
        Button {
            Haptics.selection()
            localFeedback = value
            onFeedback?(value)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                Text(label)
                    .font(Tokens.Font.footnote.bold())
            }
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .background(
                Capsule().fill(Tokens.Palette.primarySoft)
            )
        }
        .buttonStyle(.plain)
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
