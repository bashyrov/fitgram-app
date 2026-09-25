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
                        sectionsGrid
                        nextWeekRules
                        insightsSection
                        if onFeedback != nil {
                            feedbackRow
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(L("How you're doing")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onOpenHistory {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            onOpenHistory()
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                        }
                        .accessibilityLabel(Text(L("History")))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Close"), action: onDismiss)
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(Tokens.Palette.onPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(
                        TL(
                            pl: "Tygodniowy coach Ola", en: "Ola weekly coach", uk: "Тижневий коуч Ola",
                            ru: "Недельный коуч Ola", es: "Coach semanal Ola")
                    )
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
        .padding(Tokens.Space.lg)
        .frostedGlass(cornerRadius: 30, fillOpacity: 0.86, borderOpacity: 0.05, glowOpacity: 0.08)
        .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 24, y: 12)
    }

    private var rangeCaption: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "d MMMM"
        let from = debrief.rangeStart
        let to = Calendar.current.date(byAdding: .day, value: -1, to: debrief.rangeEnd) ?? debrief.generatedAt
        return "\(formatter.string(from: from)) – \(formatter.string(from: to))"
    }

    // MARK: - Stats grid

    private var statsGrid: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(
                    TL(
                        pl: "Twoje statystyki", en: "Your stats", uk: "Твоя статистика", ru: "Твоя статистика",
                        es: "Tus estadísticas")
                )
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

    private var sectionsGrid: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(
                TL(
                    pl: "Co zauważyła Ola", en: "What Ola noticed", uk: "Що помітила Ola", ru: "Что заметила Ola",
                    es: "Lo que notó Ola")
            )
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Palette.ink)
            ForEach(debrief.sections) { section in
                insightSectionCard(section)
            }
        }
    }

    private func insightSectionCard(_ section: WeeklyDebrief.Section) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: section.symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Tokens.Palette.primarySoft.opacity(0.78)))
            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(section.body)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .frostedGlass(cornerRadius: 24, fillOpacity: 0.78, borderOpacity: 0.04, glowOpacity: 0.04)
    }

    private var nextWeekRules: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(
                TL(
                    pl: "3 zasady na kolejny tydzień", en: "3 rules for next week",
                    uk: "3 правила на наступний тиждень", ru: "3 правила на следующую неделю",
                    es: "3 reglas para la próxima semana")
            )
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(Array(debrief.nextWeekRules.enumerated()), id: \.offset) { index, rule in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text("\(index + 1)")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundStyle(Tokens.Palette.onPrimary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Tokens.Palette.primary))
                        Text(rule)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(Tokens.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Tokens.Palette.surfaceMuted.opacity(0.70))
                    )
                }
            }
            .padding(Tokens.Space.sm)
            .frostedGlass(cornerRadius: 26, fillOpacity: 0.80, borderOpacity: 0.04, glowOpacity: 0.04)
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
                            ? TL(
                                pl: "Dzięki za opinię!", en: "Thanks for the feedback!", uk: "Дякуємо за відгук!",
                                ru: "Спасибо за отзыв!", es: "¡Gracias por tu opinión!")
                            : TL(
                                pl: "Zanotowane — Ola postara się lepiej dopasować.",
                                en: "Noted — Ola will try to fit you better.",
                                uk: "Записано — Ola спробує краще підлаштуватися.",
                                ru: "Записано — Ola попробует лучше подстроиться.",
                                es: "Anotado: Ola intentará adaptarse mejor."
                            )
                    )
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.ink)
                    Spacer(minLength: 0)
                }
            }
        } else {
            Card {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text(TL(pl: "Pomocne?", en: "Helpful?", uk: "Корисно?", ru: "Полезно?", es: "¿Útil?"))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    HStack(spacing: Tokens.Space.md) {
                        feedbackButton(
                            value: true, symbol: "hand.thumbsup",
                            label: TL(pl: "Tak", en: "Yes", uk: "Так", ru: "Да", es: "Sí"))
                        feedbackButton(
                            value: false, symbol: "hand.thumbsdown",
                            label: TL(pl: "Nie", en: "No", uk: "Ні", ru: "Нет", es: "No"))
                    }
                }
            }
        }
    }

    private func feedbackButton(value: Bool, symbol: String, label: String) -> some View {
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
                Text(
                    TL(pl: "Wskazówka Oli", en: "Ola insight", uk: "Порада Ola", ru: "Совет Ola", es: "Insight de Ola")
                )
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
                ForEach(debrief.insights) { insight in
                    AIInsightCard(insight: insight, onAction: onCoachAction)
                }
            }
        }
    }
}
