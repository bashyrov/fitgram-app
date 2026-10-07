import OSLog
import SwiftUI

// swiftlint:disable file_length

/// Full-screen "Porady od Oli". This screen is intentionally coach-only:
/// educational facts live in `FactsLibraryView`.
@MainActor
struct OlaTipsView: View {
    private static let logger = Logger(subsystem: "app.fitgram", category: "OlaTipsView")

    let recommendations: Recommendations?
    let dailyPlan: DailyOlaPlan?
    let coachInsights: [CoachInsight]
    let lastUpdated: Date?
    let onDismiss: () -> Void

    @State private var selectedCategory: OlaAdviceCategory = .today
    @State private var helpfulTipIDs: Set<String> = []
    @State private var notHelpfulTipIDs: Set<String> = []

    private var feed: OlaTipFeed {
        OlaTipFeed(coachInsights: coachInsights, dailyPlan: dailyPlan)
    }

    var body: some View {
        NavigationStack {
            tipsTab
                .background(Tokens.Palette.background.ignoresSafeArea())
                .monoNavigationTitle(
                    TL(
                        pl: "Porady od Oli", en: "Tips from Ola", uk: "Поради від Ola", ru: "Советы от Ola",
                        es: "Consejos de Ola")
                )
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        MonoNavText(title: L("Close"), action: onDismiss)
                    }
                }
        }
    }
}

// MARK: - Tips
extension OlaTipsView {
    private var tipsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    if let recs = recommendations {
                        OlaLivingHero(recommendations: recs, lastUpdated: lastUpdated)
                    } else {
                        fallbackHero
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 8)
                categoryRail
                    .padding(.top, 12)
                selectedCategoryContent(recommendations)
                    .padding(.horizontal, Tokens.Space.screenPadding)
            }
            .padding(.bottom, 34)
        }
        .scrollIndicators(.hidden)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(OlaAdviceCategory.allCases) { category in
                    MonoChip(title: category.title, isSelected: selectedCategory == category) {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                        Haptics.light()
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    @ViewBuilder
    private func selectedCategoryContent(_ recs: Recommendations?) -> some View {
        switch selectedCategory {
        case .today:
            todayContent(recs)
        case .protein, .calories, .habits:
            categoryContent(recs)
        case .memory:
            memoryPanel(recs, number: "01", top: 22)
        case .history:
            historyPanel(recs)
        }
    }

    private func todayContent(_ recs: Recommendations?) -> some View {
        let tips = feed.todayTips(from: recs)
        let hasPlan = dailyPlan != nil
        let warnings = recs?.warnings ?? []
        let tipsNumber = hasPlan ? 2 : 1
        let warningsNumber = tipsNumber + 1
        let memoryNumber = warnings.isEmpty ? warningsNumber : warningsNumber + 1
        return VStack(alignment: .leading, spacing: 0) {
            if let dailyPlan {
                OlaTipsSectionHead(number: "01", title: L("Plan na dziś"), top: 22) {
                    MonoLabel(
                        text: TL(pl: "Ola dziś", en: "Ola today", uk: "Ola сьогодні", ru: "Ola сегодня", es: "Ola hoy"))
                }
                if dailyPlan.source == .fallback {
                    aiUnavailableCard
                        .padding(.bottom, 8)
                }
                dailyPlanCard(dailyPlan)
            }
            OlaTipsSectionHead(
                number: Self.sectionNumber(tipsNumber), title: L("Wskazówki na dziś"), top: hasPlan ? 28 : 22
            ) {
                MonoLabel(text: "\(tips.count)")
            }
            adviceCards(tips)
            if !warnings.isEmpty {
                OlaTipsSectionHead(
                    number: Self.sectionNumber(warningsNumber),
                    title: TL(pl: "Ostrzeżenia", en: "Warnings", uk: "Попередження", ru: "Предупреждения", es: "Avisos")
                )
                OlaWarningsBlock(warnings: warnings)
            }
            memoryPanel(recs, number: Self.sectionNumber(memoryNumber), top: 28)
            historyShortcut(tips)
        }
    }

    private func categoryContent(_ recs: Recommendations?) -> some View {
        let tips = feed.tips(for: selectedCategory, in: recs)
        return VStack(alignment: .leading, spacing: 0) {
            OlaTipsSectionHead(number: "01", title: selectedCategory.title, top: 22) {
                MonoLabel(text: "\(tips.count)")
            }
            if tips.isEmpty {
                emptyCategoryCard
            } else {
                adviceCards(tips)
            }
        }
    }

    private func adviceCards(_ tips: [RecommendationTip]) -> some View {
        VStack(spacing: 8) {
            ForEach(tips) { tip in
                OlaAdviceCard(
                    tip: tip,
                    isHelpful: helpfulTipIDs.contains(reactionID(for: tip)),
                    isNotHelpful: notHelpfulTipIDs.contains(reactionID(for: tip)),
                    onHelpful: { mark(tip, helpful: true) },
                    onNotHelpful: { mark(tip, helpful: false) },
                    category: categoryLabel(for: tip)
                )
            }
        }
    }

    private func categoryLabel(for tip: RecommendationTip) -> String? {
        if selectedCategory == .protein || selectedCategory == .calories || selectedCategory == .habits {
            return selectedCategory.title
        }
        let haystack = "\(tip.title) \(tip.description)".lowercased()
        let match = [OlaAdviceCategory.protein, .calories, .habits].first { category in
            category.keywords.contains { haystack.localizedCaseInsensitiveContains($0) }
        }
        return match?.title
    }

    private static func sectionNumber(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private var emptyCategoryCard: some View {
        VStack(spacing: 12) {
            MonoIconBox(systemName: "checkmark", style: .dark, size: 72)
            Text(L("Everything is calm here"))
                .font(Tokens.Font.monoDisplay(24))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
            Text(
                TL(
                    pl: "Ola nie widzi teraz nic pilnego w tej kategorii.",
                    en: "Ola does not see anything urgent in this category right now.",
                    uk: "Ola зараз не бачить нічого термінового в цій категорії.",
                    ru: "Ola сейчас не видит ничего срочного в этой категории.",
                    es: "Ola no ve nada urgente en esta categoría ahora."
                )
            )
            .font(Tokens.Font.manrope(14, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 48)
    }

    private func dailyPlanCard(_ plan: DailyOlaPlan) -> some View {
        let focuses = Array(plan.focuses.prefix(4))
        let columnCount = focuses.count == 4 ? 2 : max(1, min(3, focuses.count))
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: columnCount)
        return VStack(alignment: .leading, spacing: 14) {
            Text(plan.headline)
                .font(Tokens.Font.monoDisplay(20))
                .foregroundStyle(Tokens.Mono.onHero)
                .fixedSize(horizontal: false, vertical: true)
            Text(plan.body)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
            if !focuses.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                    ForEach(focuses) { focus in
                        focusTile(focus)
                    }
                }
            }
            planLine(
                symbol: "target",
                tint: Tokens.Mono.hi,
                label: TL(pl: "Cel dnia", en: "Today's goal", uk: "Ціль дня", ru: "Цель дня", es: "Objetivo del día"),
                text: plan.todayGoal
            )
            if let risk = plan.risk {
                planLine(symbol: "exclamationmark.triangle", tint: Tokens.Mono.fat, label: L("Ryzyko dnia"), text: risk)
                    .padding(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Tokens.Mono.heroLine, lineWidth: 1)
                    )
            }
            planLine(
                symbol: "clock", tint: Tokens.Mono.hi, label: L("Pierwszy posiłek"), text: plan.firstMealSuggestion)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private func focusTile(_ focus: DailyOlaPlan.Focus) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(focus.title)
                .font(Tokens.Font.manrope(10, weight: 800))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.heroMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(focus.value)
                .font(Tokens.Font.archivo(size: 15, weight: 800, width: 110))
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(focus.detail)
                .font(Tokens.Font.manrope(10, weight: 700))
                .foregroundStyle(Tokens.Mono.hi)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.Mono.heroLine)
        )
    }

    private func planLine(symbol: String, tint: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                MonoLabel(text: label, onHero: true)
                Text(text)
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Fallback states
extension OlaTipsView {
    private var aiUnavailableCard: some View {
        HStack(alignment: .center, spacing: 10) {
            MonoIconBox(systemName: "exclamationmark.triangle", style: .track, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    TL(
                        pl: "Ola używa bezpiecznego planu", en: "Ola is using a safe backup",
                        uk: "Ola використовує безпечний план", ru: "Ola использует безопасный план",
                        es: "Ola usa un plan seguro")
                )
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl:
                            "AI teraz nie odpowiada, więc Fitgram pokazuje mądry plan lokalny. Nadal możesz dodawać posiłki ręcznie.",
                        en:
                            "AI is not responding right now, so Fitgram shows a smart local plan. You can still add meals manually.",
                        uk:
                            "AI зараз не відповідає, тому Fitgram показує розумний локальний план. Ти все ще можеш додавати їжу вручну.",
                        ru:
                            """
                            AI сейчас не отвечает, поэтому Fitgram показывает умный локальный план. Ты все еще можешь добавлять еду \
                            вручную.
                            """,
                        es:
                            """
                            La IA no responde ahora, así que Fitgram muestra un plan local inteligente. Aún puedes añadir comidas \
                            manualmente.
                            """
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    private var fallbackHero: some View {
        HStack(alignment: .center, spacing: 12) {
            MonoIconBox(systemName: "sparkles", style: .hi, size: 52)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Ola"))
                    .font(Tokens.Font.monoNumber(30))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.onHero)
                Text(
                    TL(
                        pl: "Twój spokojny coach od decyzji żywieniowych", en: "Your calm coach for food decisions",
                        uk: "Твій спокійний коуч для рішень про їжу", ru: "Твой спокойный коуч для решений о еде",
                        es: "Tu coach tranquila para decisiones de comida")
                )
                .font(Tokens.Font.manrope(13, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }
}

// MARK: - Memory + history
extension OlaTipsView {
    private func memoryPanel(_ recs: Recommendations?, number: String, top: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OlaTipsSectionHead(
                number: number,
                title: TL(
                    pl: "Pamięć Oli", en: "Ola memory", uk: "Памʼять Ola", ru: "Память Ola", es: "Memoria de Ola"),
                top: top
            )
            VStack(spacing: 0) {
                OlaMemoryRow(
                    symbol: "target",
                    title: L("Your plan"),
                    value: recs?.nextSteps.isEmpty == false
                        ? recs?.nextSteps ?? ""
                        : dailyPlan?.todayGoal
                            ?? TL(
                                pl: "Ola dopasowuje plan do Twojej aktualnej normy.",
                                en: "Ola adjusts the plan to your current target.",
                                uk: "Ola підлаштовує план під твою поточну норму.",
                                ru: "Ola подстраивает план под твою текущую норму.",
                                es: "Ola ajusta el plan a tu objetivo actual."
                            ),
                    tint: Tokens.Palette.primary
                )
                MonoRowDivider()
                OlaMemoryRow(
                    symbol: "sparkles",
                    title: L("Conversation style"),
                    value: TL(
                        pl: "Krótko, konkretnie i bez presji. Ola podpowiada następny mały ruch.",
                        en: "Short, specific and pressure-free. Ola suggests the next small move.",
                        uk: "Коротко, конкретно і без тиску. Ola підказує наступний маленький крок.",
                        ru: "Коротко, конкретно и без давления. Ola подсказывает следующий маленький шаг.",
                        es: "Corto, concreto y sin presión. Ola sugiere el siguiente pequeño paso."
                    ),
                    tint: Tokens.Palette.accent
                )
                MonoRowDivider()
                OlaMemoryRow(
                    symbol: "clock",
                    title: L("Last update"),
                    value: lastUpdated?.formatted(date: .abbreviated, time: .shortened)
                        ?? TL(
                            pl: "Po pierwszych posiłkach", en: "After the first meals", uk: "Після перших прийомів їжі",
                            ru: "После первых приемов пищи", es: "Después de las primeras comidas"),
                    tint: Tokens.Palette.warning
                )
            }
            .monoRowsCard()
        }
    }

    /// "Historia porad" row under the memory card on the Today tab — jumps to the history tab.
    private func historyShortcut(_ tips: [RecommendationTip]) -> some View {
        Button {
            withAnimation(Tokens.Motion.gentle) {
                selectedCategory = .history
            }
            Haptics.light()
        } label: {
            MonoRow(
                icon: "clock.arrow.circlepath",
                title: L("Advice history"),
                sub: tips.first.map { L($0.title) }
            )
            .monoRowsCard()
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private func historyPanel(_ recs: Recommendations?) -> some View {
        let tips = Array(feed.todayTips(from: recs).prefix(8))
        return VStack(alignment: .leading, spacing: 0) {
            OlaTipsSectionHead(number: "01", title: L("Advice history"), top: 22) {
                MonoLabel(text: "\(tips.count)")
            }
            VStack(spacing: 0) {
                ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                    if index > 0 {
                        MonoRowDivider()
                    }
                    HStack(alignment: .center, spacing: 12) {
                        OlaEmojiBox(emoji: tip.icon)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L(tip.title))
                                .font(Tokens.Font.manrope(15, weight: 800))
                                .foregroundStyle(Tokens.Palette.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(
                                index == 0
                                    ? TL(
                                        pl: "Najnowsza rada", en: "Newest tip", uk: "Найновіша порада",
                                        ru: "Самый новый совет", es: "Consejo más reciente")
                                    : TL(
                                        pl: "Wróć do tej wskazówki później", en: "Return to this tip later",
                                        uk: "Повернись до цієї поради пізніше", ru: "Вернись к этому совету позже",
                                        es: "Vuelve a este consejo más tarde")
                            )
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 13)
                    .padding(.horizontal, 16)
                }
            }
            .monoRowsCard()
        }
    }
}

// MARK: - Reactions
extension OlaTipsView {
    private func mark(_ tip: RecommendationTip, helpful: Bool) {
        let id = reactionID(for: tip)
        withAnimation(Tokens.Motion.gentle) {
            if helpful {
                helpfulTipIDs.insert(id)
                notHelpfulTipIDs.remove(id)
            } else {
                notHelpfulTipIDs.insert(id)
                helpfulTipIDs.remove(id)
            }
        }
        Haptics.light()
    }

    private func reactionID(for tip: RecommendationTip) -> String {
        "\(tip.title)|\(tip.description)"
    }

    private var emptyRecommendationsState: some View {
        VStack(spacing: 10) {
            MonoIconBox(systemName: "sparkles", style: .track, size: 52)
            Text(L("Ola jeszcze nie ma porad"))
                .font(Tokens.Font.manrope(16, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(L("Zaloguj kilka posiłków, a wrócimy z gotowymi wskazówkami."))
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 30)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.line2).frame(height: 1)
        }
    }
}

/// Section header used on Ola's screen (lib `sec`): 20 pt display title, hairline, +6 pt inset.
private struct OlaTipsSectionHead<Trailing: View>: View {
    let number: String?
    let title: String
    var top: CGFloat = 28
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        MonoSectionHeader(number: number, title: title, trailing: trailing)
            .padding(.top, max(0, top - Tokens.Space.lg))
            .padding(.horizontal, 6)
            .padding(.bottom, 12)
    }
}

extension OlaTipsSectionHead where Trailing == EmptyView {
    init(number: String?, title: String, top: CGFloat = 28) {
        self.init(number: number, title: title, top: top) { EmptyView() }
    }
}
