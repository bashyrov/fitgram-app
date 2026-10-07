import SwiftUI

/// "Wyzwania tygodnia" sheet — auto-rolling challenges for the current
/// ISO week. Read-only; the user doesn't pick — every challenge runs
/// in parallel and progress comes from the meal log.
struct ChallengesView: View {
    let progress: [ChallengeProgress]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        intro
                        Color.clear.frame(height: 16)
                        VStack(spacing: 8) {
                            ForEach(progress) { item in
                                ChallengeCard(item: item)
                            }
                        }
                        Color.clear.frame(height: 12)
                        MonoHint(
                            text: L(
                                "All challenges run in parallel. You don't have to choose anything — every meal counts on its own."
                            )
                        )
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, 24)
                }
            }
            .monoNavigationTitle(L("Wyzwania tygodnia"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
        }
    }

    private var intro: some View {
        MonoH1(text: L("Twój tydzień"), sub: introSubtitle, kicker: L("Wyzwania tygodnia"))
    }

    /// "29 wrz – 5 paź · 2 z 6 ukończone".
    private var introSubtitle: String {
        let done = progress.filter(\.isCompleted).count
        let summary = TL(
            pl: "\(done) z \(progress.count) ukończone",
            en: "\(done) of \(progress.count) completed",
            uk: "\(done) з \(progress.count) виконано",
            ru: "\(done) из \(progress.count) выполнено",
            es: "\(done) de \(progress.count) completados"
        )
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()),
            let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end)
        else { return summary }
        let style = Date.FormatStyle().day().month(.abbreviated).locale(calendar.locale ?? .current)
        return "\(week.start.formatted(style)) – \(lastDay.formatted(style)) · \(summary)"
    }
}

private struct ChallengeCard: View {
    let item: ChallengeProgress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(item.challenge.title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text("\(item.current) / \(item.challenge.rule.target)")
                    .font(Tokens.Font.monoNumber(16))
                    .foregroundStyle(Tokens.Palette.ink)
            }
            MonoBar(progress: item.ratio, color: accent, height: 8)
            if !item.challenge.body.isEmpty {
                Text(item.challenge.body)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monoCard(padding: 16)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(item.isCompleted ? L("Zdobyte") : ""))
    }

    private var accent: Color {
        item.isCompleted ? Tokens.Mono.accent : Tokens.Mono.strong
    }
}
