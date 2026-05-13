import Foundation

/// Pure-function rule engine. Each rule returns at most one insight; the
/// engine concatenates and trims to `maxInsights`. Order matters — earlier
/// rules win the headline slot on Today, so we run celebrations and
/// at-risk nudges before generic encouragements.
struct RuleBasedCoach: CoachInsightGenerator {
    var maxInsights: Int = 3

    func generate(for context: CoachContext) -> [CoachInsight] {
        var insights: [CoachInsight] = []
        for rule in Self.rules {
            if let insight = rule(context) {
                insights.append(insight)
                if insights.count >= maxInsights { break }
            }
        }
        if insights.isEmpty {
            insights.append(Self.welcome(context))
        }
        return insights
    }

    private typealias Rule = (CoachContext) -> CoachInsight?

    nonisolated(unsafe) private static let rules: [Rule] = [
        celebrateStreakMilestone,
        celebrateWeightProgress,
        warnStreakAtRisk,
        suggestProtein,
        warnCalorieOvershoot,
        suggestMorningProtein,
        suggestAfternoonMomentum,
        suggestLightEvening,
        encourageBalancedWeek,
        reminderToLogFirstMeal,
    ]

    // MARK: - Rules

    private static func celebrateStreakMilestone(_ context: CoachContext) -> CoachInsight? {
        let length = context.streak.current
        guard [3, 7, 14, 21, 30, 60, 100].contains(length) else { return nil }
        return CoachInsight(
            tone: .celebration,
            headline: String(localized: "Brawo!"),
            body: String(
                localized:
                    "Już \(length) dni z rzędu z Mealgram. Spokojne tempo — to dokładnie tak, jak ma być."
            )
        )
    }

    private static func celebrateWeightProgress(_ context: CoachContext) -> CoachInsight? {
        guard let delta = context.weight.deltaKg30Days, abs(delta) >= 1 else { return nil }
        guard delta < 0 else {
            return CoachInsight(
                tone: .encouragement,
                headline: String(localized: "Spokojnie"),
                body: String(
                    localized:
                        "Mała zmiana wagi (+\(formatKg(delta))) — to normalne wahania. Spójrzmy na średnią z całego miesiąca."
                ),
                actionTitle: String(localized: "Otwórz wagę"),
                actionKind: .openWeightLog
            )
        }
        return CoachInsight(
            tone: .celebration,
            headline: String(localized: "Świetna trajektoria"),
            body: String(
                localized:
                    "W ciągu 30 dni schudłaś \(formatKg(-delta)). Konsekwencja popłaca — tak trzymać."
            )
        )
    }

    private static func warnStreakAtRisk(_ context: CoachContext) -> CoachInsight? {
        guard context.streak.atRiskToday, context.streak.current >= 2, context.hourOfDay >= 18 else { return nil }
        return CoachInsight(
            tone: .nudge,
            headline: String(localized: "Seria zagrożona"),
            body: String(
                localized:
                    "Twoja seria \(context.streak.current) dni — jeszcze nic dziś nie zapisałaś. Krótki wpis wystarczy."
            ),
            actionTitle: String(localized: "Dodaj posiłek"),
            actionKind: .openScanner
        )
    }

    private static func suggestProtein(_ context: CoachContext) -> CoachInsight? {
        guard context.goals.proteinGoalGrams > 0 else { return nil }
        let ratio = context.today.proteinGrams / Double(context.goals.proteinGoalGrams)
        // Only nudge after lunch and only if we're materially below the goal.
        guard context.hourOfDay >= 14, ratio < 0.5, context.today.entryCount > 0 else { return nil }
        let missing = Int(max(0, Double(context.goals.proteinGoalGrams) - context.today.proteinGrams))
        return CoachInsight(
            tone: .suggestion,
            headline: String(localized: "Trochę białka"),
            body: String(
                localized:
                    "Brakuje \(missing) g białka do celu. Twaróg, jajka, strączki — pasują niemal do każdego posiłku."
            ),
            actionTitle: String(localized: "Szybka baza"),
            actionKind: .openQuickDB
        )
    }

    private static func warnCalorieOvershoot(_ context: CoachContext) -> CoachInsight? {
        guard context.goals.calorieGoalKcal > 0 else { return nil }
        let ratio = context.today.caloriesKcal / Double(context.goals.calorieGoalKcal)
        guard ratio >= 1.2, context.hourOfDay < 22 else { return nil }
        return CoachInsight(
            tone: .nudge,
            headline: String(localized: "Dziś bogato"),
            body: String(
                localized:
                    "Już ponad cel kalorii. Wieczorem warto coś lekkiego — sałata, twaróg, owoce."
            )
        )
    }

    /// Morning rule (6–11): user has eaten breakfast but the protein
    /// content is light — nudge to keep mid-morning protein in mind.
    /// Skips when the day's protein is already on pace with goal.
    private static func suggestMorningProtein(_ context: CoachContext) -> CoachInsight? {
        guard context.hourOfDay >= 6, context.hourOfDay < 11 else { return nil }
        guard context.today.entryCount > 0 else { return nil }
        guard context.goals.proteinGoalGrams > 0 else { return nil }
        guard context.today.proteinGrams < 15 else { return nil }
        return CoachInsight(
            tone: .suggestion,
            headline: String(localized: "Białko na śniadanie"),
            body: String(
                localized:
                    "Śniadanie zalogowane — dorzuć trochę białka (jajka, twaróg, skyr). Łatwiej trzymać sytość do obiadu."
            ),
            actionTitle: String(localized: "Szybka baza"),
            actionKind: .openQuickDB
        )
    }

    /// Mid-afternoon rule (14–17): user is at 40–70 % of the calorie
    /// goal with at least 2 entries — encourage steady pacing without
    /// nudging them to overeat.
    private static func suggestAfternoonMomentum(_ context: CoachContext) -> CoachInsight? {
        guard context.hourOfDay >= 14, context.hourOfDay < 17 else { return nil }
        guard context.today.entryCount >= 2 else { return nil }
        guard context.goals.calorieGoalKcal > 0 else { return nil }
        let ratio = context.today.caloriesKcal / Double(context.goals.calorieGoalKcal)
        guard ratio >= 0.4, ratio < 0.7 else { return nil }
        return CoachInsight(
            tone: .encouragement,
            headline: String(localized: "Dobre tempo"),
            body: String(
                localized:
                    "Pół dnia za Tobą i ładnie w limicie. Lekka przekąska + kolacja domyka dzień."
            )
        )
    }

    private static func suggestLightEvening(_ context: CoachContext) -> CoachInsight? {
        guard context.hourOfDay >= 17, context.hourOfDay < 22 else { return nil }
        guard context.goals.calorieGoalKcal > 0 else { return nil }
        let ratio = context.today.caloriesKcal / Double(context.goals.calorieGoalKcal)
        guard ratio >= 0.7, ratio < 1.0 else { return nil }
        return CoachInsight(
            tone: .suggestion,
            headline: String(localized: "Wszystko na kursie"),
            body: String(
                localized:
                    "Jesteś bliska celu. Lekka kolacja albo przekąska — i wystarczy."
            )
        )
    }

    private static func encourageBalancedWeek(_ context: CoachContext) -> CoachInsight? {
        guard context.week.daysWithinCalorieGoal >= 5 else { return nil }
        return CoachInsight(
            tone: .celebration,
            headline: String(localized: "Świetny tydzień"),
            body: String(
                localized:
                    "5 z ostatnich 7 dni w celu kalorii. To bardziej liczy się niż jeden idealny dzień."
            )
        )
    }

    private static func reminderToLogFirstMeal(_ context: CoachContext) -> CoachInsight? {
        guard context.today.entryCount == 0 else { return nil }
        if context.hourOfDay < 10 {
            return CoachInsight(
                tone: .encouragement,
                headline: String(localized: "Dzień dobry"),
                body: String(
                    localized:
                        "Co dziś planujesz na śniadanie? Stuknij plusik, gdy będzie gotowe."
                ),
                actionTitle: String(localized: "Dodaj posiłek"),
                actionKind: .openScanner
            )
        }
        if context.hourOfDay < 15 {
            return CoachInsight(
                tone: .suggestion,
                headline: String(localized: "Pora obiadu"),
                body: String(
                    localized:
                        "Jeszcze nic dziś nie zapisałaś — dorzuć obiad, żebym mogła ułożyć dzień."
                ),
                actionTitle: String(localized: "Dodaj posiłek"),
                actionKind: .openScanner
            )
        }
        return CoachInsight(
            tone: .nudge,
            headline: String(localized: "Pusty dzień"),
            body: String(
                localized:
                    "Wpiszmy choć jeden posiłek — nie chcemy stracić serii."
            ),
            actionTitle: String(localized: "Dodaj posiłek"),
            actionKind: .openScanner
        )
    }

    private static func welcome(_ context: CoachContext) -> CoachInsight {
        CoachInsight(
            tone: .encouragement,
            headline: String(localized: "Spokojny dzień"),
            body: String(
                localized:
                    "Wszystko wygląda zdrowo. Nie zapominaj o wodzie — to często prosty brakujący puzzel."
            )
        )
    }

    private static func formatKg(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.decimalSeparator = ","
        return (formatter.string(from: NSNumber(value: value)) ?? "0") + " kg"
    }
}
