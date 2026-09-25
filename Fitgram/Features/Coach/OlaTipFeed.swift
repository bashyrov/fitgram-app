import Foundation

/// Assembles the tip lists on Ola's screen from the coach insights,
/// today's plan and the stored recommendations. Pure — no view state.
struct OlaTipFeed {
    let coachInsights: [CoachInsight]
    let dailyPlan: DailyOlaPlan?

    func tips(for category: OlaAdviceCategory, in recs: Recommendations?) -> [RecommendationTip] {
        let keywords = category.keywords
        let allTips = todayTips(from: recs)
        guard !keywords.isEmpty else { return allTips }
        let matched = allTips.filter { tip in
            let haystack = "\(tip.title) \(tip.description)".lowercased()
            return keywords.contains { haystack.localizedCaseInsensitiveContains($0) }
        }
        return matched.isEmpty ? Array(allTips.prefix(2)) : matched
    }

    func todayTips(from recs: Recommendations?) -> [RecommendationTip] {
        var tips = insightTips
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
            tips = Self.fallbackTips
        }
        return Array(tips.prefix(10))
    }

    var insightTips: [RecommendationTip] {
        coachInsights.map(Self.recommendationTip(from:))
    }

    private static func recommendationTip(from insight: CoachInsight) -> RecommendationTip {
        RecommendationTip(
            icon: icon(for: insight),
            title: insight.headline,
            description: insight.body
        )
    }

    private static func icon(for insight: CoachInsight) -> String {
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

    private static var fallbackTips: [RecommendationTip] {
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
}
