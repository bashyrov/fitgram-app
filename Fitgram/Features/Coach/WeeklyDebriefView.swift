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
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                        .padding(.top, 8)
                    WeeklySectionHead(
                        number: "01",
                        title: TL(
                            pl: "Twoje statystyki", en: "Your stats", uk: "Твоя статистика", ru: "Твоя статистика",
                            es: "Tus estadísticas"),
                        top: 24
                    )
                    statsGrid
                    if !debrief.sections.isEmpty {
                        WeeklySectionHead(
                            number: "02",
                            title: TL(
                                pl: "Co zauważyła Ola", en: "What Ola noticed", uk: "Що помітила Ola",
                                ru: "Что заметила Ola",
                                es: "Lo que notó Ola")
                        )
                        sectionsList
                    }
                    if !debrief.nextWeekRules.isEmpty {
                        WeeklySectionHead(
                            number: debrief.sections.isEmpty ? "02" : "03",
                            title: TL(
                                pl: "3 zasady na kolejny tydzień", en: "3 rules for next week",
                                uk: "3 правила на наступний тиждень", ru: "3 правила на следующую неделю",
                                es: "3 reglas para la próxima semana")
                        )
                        nextWeekRules
                    }
                    insightsSection
                    if onFeedback != nil {
                        feedbackRow
                            .padding(.top, 12)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("How you're doing"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
                if let onOpenHistory {
                    ToolbarItem(placement: .topBarTrailing) {
                        MonoNavIcon(systemName: "clock.arrow.circlepath", accessibilityLabel: L("History")) {
                            onOpenHistory()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(
                text: TL(
                    pl: "Tygodniowy coach Ola", en: "Ola weekly coach", uk: "Тижневий коуч Ola",
                    ru: "Недельный коуч Ola", es: "Coach semanal Ola"),
                onHero: true
            )
            Text(debrief.headline)
                .font(Tokens.Font.monoDisplay(32))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.onHero)
                .fixedSize(horizontal: false, vertical: true)
            Text(rangeCaption)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
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
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            ForEach(debrief.stats) { stat in
                statTile(stat)
            }
        }
    }

    private var sectionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(debrief.sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    MonoRowDivider()
                }
                MonoRow(icon: section.symbol, title: section.title, sub: section.body) {
                    EmptyView()
                }
            }
        }
        .monoRowsCard()
    }

    private var nextWeekRules: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(debrief.nextWeekRules.enumerated()), id: \.offset) { index, rule in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)")
                        .font(Tokens.Font.monoNumber(15))
                        .foregroundStyle(Tokens.Mono.hi)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Tokens.Mono.hero))
                    Text(rule)
                        .font(Tokens.Font.manrope(14, weight: 700))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                    Spacer(minLength: 0)
                }
            }
        }
        .monoCard(padding: 18)
    }

    private func statTile(_ stat: WeeklyDebrief.Stat) -> some View {
        let parts = Self.splitUnit(stat.value)
        return VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: stat.caption)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(parts.value)
                    .font(Tokens.Font.monoNumber(26))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit = parts.unit {
                    Text(unit)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
        }
        .monoTile()
    }

    /// "1760 kcal" → ("1760", "kcal"); plain numbers keep `unit == nil`.
    private static func splitUnit(_ text: String) -> (value: String, unit: String?) {
        guard let space = text.lastIndex(of: " ") else { return (text, nil) }
        let unit = String(text[text.index(after: space)...])
        guard !unit.isEmpty, unit.allSatisfy({ !$0.isNumber }) else { return (text, nil) }
        return (String(text[..<space]), unit)
    }

    // MARK: - Feedback

    private var resolvedFeedback: Bool? { localFeedback ?? existingFeedback }

    @ViewBuilder
    private var feedbackRow: some View {
        if let value = resolvedFeedback {
            HStack(spacing: 12) {
                MonoIconBox(systemName: value ? "hand.thumbsup.fill" : "hand.thumbsdown.fill", style: .track, size: 36)
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
                .font(Tokens.Font.manrope(14, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .monoCard(padding: 16)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(TL(pl: "Pomocne?", en: "Helpful?", uk: "Корисно?", ru: "Полезно?", es: "¿Útil?"))
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                HStack(spacing: 8) {
                    feedbackButton(
                        value: true, symbol: "hand.thumbsup", kind: .dark,
                        label: TL(pl: "Tak", en: "Yes", uk: "Так", ru: "Да", es: "Sí"))
                    feedbackButton(
                        value: false, symbol: "hand.thumbsdown", kind: .outline,
                        label: TL(pl: "Nie", en: "No", uk: "Ні", ru: "Нет", es: "No"))
                }
            }
            .monoCard(padding: 16)
        }
    }

    private func feedbackButton(value: Bool, symbol: String, kind: MonoButtonKind, label: String) -> some View {
        MonoButton(title: label, kind: kind, icon: symbol, height: 46) {
            Haptics.selection()
            localFeedback = value
            onFeedback?(value)
        }
    }

    // MARK: - Insights section

    @ViewBuilder
    private var insightsSection: some View {
        if debrief.insights.isEmpty {
            EmptyView()
        } else {
            WeeklySectionHead(
                number: nil,
                title: TL(
                    pl: "Wskazówka Oli", en: "Ola insight", uk: "Порада Ola", ru: "Совет Ola", es: "Insight de Ola")
            )
            VStack(spacing: 8) {
                ForEach(debrief.insights) { insight in
                    AIInsightCard(insight: insight, onAction: onCoachAction)
                }
            }
        }
    }
}

/// Section header (lib `sec`): 20 pt display title with hairline, +6 pt inset, 28 pt top margin.
private struct WeeklySectionHead: View {
    let number: String?
    let title: String
    var top: CGFloat = 28

    var body: some View {
        MonoSectionHeader(number: number, title: title)
            .padding(.top, max(0, top - Tokens.Space.lg))
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
    }
}
