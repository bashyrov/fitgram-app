import OSLog
import SwiftUI

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

    var body: some View {
        NavigationStack {
            ZStack {
                olaBackground
                tipsTab
            }
            .navigationTitle(
                Text(
                    TL(
                        pl: "Porady od Oli", en: "Tips from Ola", uk: "Поради від Ola", ru: "Советы от Ola",
                        es: "Consejos de Ola"))
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Close"), action: onDismiss)
                }
            }
        }
    }

    private var olaBackground: some View {
        ScreenBackground(mood: .coach)
    }

    @ViewBuilder
    private var tipsTab: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Tokens.Space.lg) {
                if let recs = recommendations {
                    OlaLivingHero(recommendations: recs, lastUpdated: lastUpdated)
                } else {
                    fallbackHero
                }
                if let dailyPlan {
                    if dailyPlan.source == .fallback {
                        aiUnavailableCard
                    }
                    dailyPlanCard(dailyPlan)
                }
                categoryRail
                selectedCategoryContent(recommendations)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xxl)
        }
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(OlaAdviceCategory.allCases) { category in
                    Button {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                        Haptics.light()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 12, weight: .bold))
                            Text(category.title)
                                .font(Tokens.Font.caption.weight(.bold))
                        }
                        .foregroundStyle(selectedCategory == category ? .white : Tokens.Palette.ink)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedCategory == category ? category.tint : Tokens.Palette.surface.opacity(0.84))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedCategory == category ? .clear : .white.opacity(0.36), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func selectedCategoryContent(_ recs: Recommendations?) -> some View {
        switch selectedCategory {
        case .today:
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                if let recs, !recs.warnings.isEmpty {
                    OlaWarningsBlock(warnings: recs.warnings)
                }
                insightList
                adviceList(title: L("Wskazówki na dziś"), tips: todayTips(from: recs))
            }
        case .protein, .calories, .habits:
            adviceList(title: selectedCategory.title, tips: tips(for: selectedCategory, in: recs))
        case .memory:
            memoryPanel(recs)
        case .history:
            historyPanel(recs)
        }
    }

    private func adviceList(title: String, tips: [RecommendationTip]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, 2)
            if tips.isEmpty {
                emptyCategoryCard
            } else {
                VStack(spacing: Tokens.Space.sm) {
                    ForEach(tips) { tip in
                        OlaAdviceCard(
                            tip: tip,
                            isHelpful: helpfulTipIDs.contains(reactionID(for: tip)),
                            isNotHelpful: notHelpfulTipIDs.contains(reactionID(for: tip)),
                            onHelpful: { mark(tip, helpful: true) },
                            onNotHelpful: { mark(tip, helpful: false) }
                        )
                    }
                }
            }
        }
    }

    private var emptyCategoryCard: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Palette.success)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Tokens.Palette.success.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(L("Everything is calm here"))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Ola nie widzi teraz nic pilnego w tej kategorii.",
                        en: "Ola does not see anything urgent in this category right now.",
                        uk: "Ola зараз не бачить нічого термінового в цій категорії.",
                        ru: "Ola сейчас не видит ничего срочного в этой категории.",
                        es: "Ola no ve nada urgente en esta categoría ahora."
                    )
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
    }

    @ViewBuilder
    private var insightList: some View {
        if !coachInsights.isEmpty {
            adviceList(title: L("Aktualne wskazówki"), tips: coachInsights.map(recommendationTip(from:)))
        }
    }

    private func dailyPlanCard(_ plan: DailyOlaPlan) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(Tokens.Palette.onPrimary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Tokens.Palette.primary))
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Plan na dziś"))
                        .font(Tokens.Font.caption.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(plan.todayGoal)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Text(plan.body)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(plan.focuses.prefix(4)) { focus in
                    HStack(spacing: Tokens.Space.sm) {
                        Text(focus.title)
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer(minLength: 0)
                        Text(focus.value)
                            .font(Tokens.Font.caption.weight(.heavy))
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    Text(focus.detail)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let risk = plan.risk {
                Text(risk)
                    .font(Tokens.Font.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(plan.firstMealSuggestion)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 26, fillOpacity: 0.86, borderOpacity: 0.04, glowOpacity: 0.08)
    }

    private var aiUnavailableCard: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Palette.warning)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Tokens.Palette.warning.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(
                    TL(
                        pl: "Ola używa bezpiecznego planu", en: "Ola is using a safe backup",
                        uk: "Ola використовує безпечний план", ru: "Ola использует безопасный план",
                        es: "Ola usa un plan seguro")
                )
                .font(Tokens.Font.bodyEmphasized)
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
                            "AI сейчас не отвечает, поэтому Fitgram показывает умный локальный план. Ты все еще можешь добавлять еду вручную.",
                        es:
                            "La IA no responde ahora, así que Fitgram muestra un plan local inteligente. Aún puedes añadir comidas manualmente."
                    )
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 24, fillOpacity: 0.82, borderOpacity: 0.04, glowOpacity: 0.04)
    }

    private var fallbackHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(L("Ola"))
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
            Text(
                TL(
                    pl: "Twój spokojny coach od decyzji żywieniowych", en: "Your calm coach for food decisions",
                    uk: "Твій спокійний коуч для рішень про їжу", ru: "Твой спокойный коуч для решений о еде",
                    es: "Tu coach tranquila para decisiones de comida")
            )
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frostedGlass(cornerRadius: 28, fillOpacity: 0.84, borderOpacity: 0.04, glowOpacity: 0.08)
    }

    private func memoryPanel(_ recs: Recommendations?) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(TL(pl: "Pamięć Oli", en: "Ola memory", uk: "Памʼять Ola", ru: "Память Ola", es: "Memoria de Ola"))
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.sm) {
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
                OlaMemoryRow(
                    symbol: "heart.text.square.fill",
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
                OlaMemoryRow(
                    symbol: "clock.arrow.circlepath",
                    title: L("Last update"),
                    value: lastUpdated?.formatted(date: .abbreviated, time: .shortened)
                        ?? TL(
                            pl: "Po pierwszych posiłkach", en: "After the first meals", uk: "Після перших прийомів їжі",
                            ru: "После первых приемов пищи", es: "Después de las primeras comidas"),
                    tint: Tokens.Palette.warning
                )
            }
        }
    }

    private func historyPanel(_ recs: Recommendations?) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(L("Advice history"))
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(Array(todayTips(from: recs).prefix(8).enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: Tokens.Space.md) {
                        Text(tip.icon)
                            .font(.system(size: 22))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Tokens.Palette.primarySoft))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
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
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Tokens.Space.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Tokens.Palette.surface.opacity(0.82))
                    )
                }
            }
        }
    }

    private func tips(for category: OlaAdviceCategory, in recs: Recommendations?) -> [RecommendationTip] {
        let keywords = category.keywords
        let allTips = todayTips(from: recs)
        guard !keywords.isEmpty else { return allTips }
        let matched = allTips.filter { tip in
            let haystack = "\(tip.title) \(tip.description)".lowercased()
            return keywords.contains { haystack.localizedCaseInsensitiveContains($0) }
        }
        return matched.isEmpty ? Array(allTips.prefix(2)) : matched
    }

    private func todayTips(from recs: Recommendations?) -> [RecommendationTip] {
        var tips = coachInsights.map(recommendationTip(from:))
        if let dailyPlan {
            tips.append(
                RecommendationTip(
                    icon: "✨",
                    title: L("Plan na dziś"),
                    description: dailyPlan.body
                )
            )
            tips.append(
                RecommendationTip(
                    icon: "🍽️",
                    title: L("Pierwszy posiłek"),
                    description: dailyPlan.firstMealSuggestion
                )
            )
            if let risk = dailyPlan.risk {
                tips.append(RecommendationTip(icon: "⚠️", title: L("Ryzyko dnia"), description: risk))
            }
        }
        tips.append(contentsOf: recs?.tips ?? [])
        if tips.isEmpty {
            tips = fallbackTips
        }
        return Array(tips.prefix(10))
    }

    private func recommendationTip(from insight: CoachInsight) -> RecommendationTip {
        RecommendationTip(
            icon: icon(for: insight),
            title: insight.headline,
            description: insight.body
        )
    }

    private func icon(for insight: CoachInsight) -> String {
        if insight.actionKind == .openWeightLog { return "⚖️" }
        if insight.actionKind == .openRecipes { return "🍽️" }
        if insight.actionKind == .openQuickDB { return "🥚" }
        switch insight.tone {
        case .celebration:
            return "✨"
        case .nudge:
            return "⚠️"
        case .suggestion:
            return "💡"
        case .encouragement:
            return "🌿"
        }
    }

    private var fallbackTips: [RecommendationTip] {
        [
            RecommendationTip(
                icon: "🥚",
                title: TL(
                    pl: "Białko najpierw", en: "Protein first", uk: "Білок першим", ru: "Белок первым",
                    es: "Proteína primero"),
                description: TL(
                    pl: "Zacznij od porcji białka, a kalorie łatwiej utrzymać do wieczora.",
                    en: "Start with a protein portion and calories are easier to keep until evening.",
                    uk: "Почни з порції білка, і калорії легше втримати до вечора.",
                    ru: "Начни с порции белка, и калории проще удержать до вечера.",
                    es: "Empieza con una porción de proteína y será más fácil mantener calorías hasta la noche.")
            ),
            RecommendationTip(
                icon: "💧",
                title: TL(
                    pl: "Woda wcześniej", en: "Water earlier", uk: "Вода раніше", ru: "Вода раньше", es: "Agua antes"),
                description: TL(
                    pl: "Pierwsza szklanka przed obiadem często zmniejsza wieczorne podjadanie.",
                    en: "The first glass before lunch often reduces evening snacking.",
                    uk: "Перша склянка до обіду часто зменшує вечірні перекуси.",
                    ru: "Первый стакан до обеда часто снижает вечерние перекусы.",
                    es: "El primer vaso antes de comer suele reducir los picoteos nocturnos.")
            ),
            RecommendationTip(
                icon: "🍽️",
                title: TL(
                    pl: "Prosty talerz", en: "Simple plate", uk: "Проста тарілка", ru: "Простая тарелка",
                    es: "Plato simple"),
                description: TL(
                    pl: "Białko, warzywa i jeden spokojny dodatek węgli wystarczą na dobry posiłek.",
                    en: "Protein, vegetables and one calm carb side are enough for a good meal.",
                    uk: "Білок, овочі та один спокійний гарнір вуглеводів достатні для хорошої їжі.",
                    ru: "Белок, овощи и один спокойный углеводный гарнир достаточны для хорошего приема пищи.",
                    es: "Proteína, verduras y un carbohidrato sencillo bastan para una buena comida.")
            ),
        ]
    }

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
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(L("Ola jeszcze nie ma porad"))
                .font(Tokens.Font.title3)
                .foregroundStyle(Tokens.Palette.ink)
            Text(L("Zaloguj kilka posiłków, a wrócimy z gotowymi wskazówkami."))
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
            Spacer()
        }
        .padding(.top, Tokens.Space.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
