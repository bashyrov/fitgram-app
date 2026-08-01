import Foundation

/// Pure-function rule engine. Each rule returns at most one insight; the
/// engine concatenates and trims to `maxInsights`. Order matters — earlier
/// rules win the headline slot on Today, so we run celebrations and
/// at-risk nudges before generic encouragements.
struct RuleBasedCoach: CoachInsightGenerator {
    var maxInsights: Int = 3

    func generate(for context: CoachContext) async -> [CoachInsight] {
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

    func generateWeekly(for context: CoachContext) async -> WeeklyDebriefAIResult {
        // Rule-based path returns the same insights as the daily call but
        // capped at 5; the headline stays nil so WeeklyDebrief.from() falls
        // back to its stat-derived heading.
        var insights: [CoachInsight] = []
        for rule in Self.rules {
            if let insight = rule(context) {
                insights.append(insight)
                if insights.count >= 5 { break }
            }
        }
        if insights.isEmpty {
            insights.append(Self.welcome(context))
        }
        return WeeklyDebriefAIResult(headline: nil, insights: insights)
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
            headline: L("Brawo!"),
            body: String.localizedStringWithFormat(L("Already %lld days in a row with Mealgram. A calm pace — exactly how it should be."), length)
        )
    }

    private static func celebrateWeightProgress(_ context: CoachContext) -> CoachInsight? {
        guard let delta = context.weight.deltaKg30Days, abs(delta) >= 1 else { return nil }
        guard delta < 0 else {
            return CoachInsight(
                tone: .encouragement,
                headline: L("Spokojnie"),
                body: String.localizedStringWithFormat(L("A small weight change (+%@) — normal fluctuation. Let's look at the whole-month average."), formatKg(delta)),
                actionTitle: L("Otwórz wagę"),
                actionKind: .openWeightLog
            )
        }
        return CoachInsight(
            tone: .celebration,
            headline: L("Świetna trajektoria"),
            body: String.localizedStringWithFormat(L("Over 30 days you lost %@. Consistency pays off — keep it up."), formatKg(-delta))
        )
    }

    private static func warnStreakAtRisk(_ context: CoachContext) -> CoachInsight? {
        guard context.streak.atRiskToday, context.streak.current >= 2, context.hourOfDay >= 18 else { return nil }
        return CoachInsight(
            tone: .nudge,
            headline: L("Seria zagrożona"),
            body: String.localizedStringWithFormat(L("Your %lld-day streak — nothing logged today yet. A quick entry is enough."), context.streak.current),
            actionTitle: L("Add meal"),
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
            headline: L("Trochę białka"),
            body: String.localizedStringWithFormat(L("%lld g of protein left to your goal. Cottage cheese, eggs, legumes — they fit almost any meal."), missing),
            actionTitle: L("Quick Database"),
            actionKind: .openQuickDB
        )
    }

    private static func warnCalorieOvershoot(_ context: CoachContext) -> CoachInsight? {
        guard context.goals.calorieGoalKcal > 0 else { return nil }
        let ratio = context.today.caloriesKcal / Double(context.goals.calorieGoalKcal)
        guard ratio >= 1.2, context.hourOfDay < 22 else { return nil }
        return CoachInsight(
            tone: .nudge,
            headline: L("Rich day today"),
            body: L("Już ponad cel kalorii. Wieczorem warto coś lekkiego — sałata, twaróg, owoce.")
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
            headline: L("Protein for breakfast"),
            body: L("Breakfast logged — add some protein (eggs, cottage cheese, skyr). It's easier to stay full until lunch."),
            actionTitle: L("Quick Database"),
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
            headline: L("Dobre tempo"),
            body: L("Pół dnia za Tobą i ładnie w limicie. Lekka przekąska + kolacja domyka dzień.")
        )
    }

    private static func suggestLightEvening(_ context: CoachContext) -> CoachInsight? {
        guard context.hourOfDay >= 17, context.hourOfDay < 22 else { return nil }
        guard context.goals.calorieGoalKcal > 0 else { return nil }
        let ratio = context.today.caloriesKcal / Double(context.goals.calorieGoalKcal)
        guard ratio >= 0.7, ratio < 1.0 else { return nil }
        return CoachInsight(
            tone: .suggestion,
            headline: L("Wszystko na kursie"),
            body: L("You're close to your goal. A light dinner or snack — that's enough.")
        )
    }

    private static func encourageBalancedWeek(_ context: CoachContext) -> CoachInsight? {
        guard context.week.daysWithinCalorieGoal >= 5 else { return nil }
        return CoachInsight(
            tone: .celebration,
            headline: L("Świetny tydzień"),
            body: L("5 out of the last 7 days within your calorie goal. This matters more than one perfect day.")
        )
    }

    private static func reminderToLogFirstMeal(_ context: CoachContext) -> CoachInsight? {
        guard context.today.entryCount == 0 else { return nil }
        if context.hourOfDay < 10 {
            return CoachInsight(
                tone: .encouragement,
                headline: L("Good morning"),
                body: L("What's for breakfast today? Tap + when it's ready."),
                actionTitle: L("Add meal"),
                actionKind: .openScanner
            )
        }
        if context.hourOfDay < 15 {
            return CoachInsight(
                tone: .suggestion,
                headline: L("Pora obiadu"),
                body: L("Jeszcze nic dziś nie zapisałaś — dorzuć obiad, żebym mogła ułożyć dzień."),
                actionTitle: L("Add meal"),
                actionKind: .openScanner
            )
        }
        return CoachInsight(
            tone: .nudge,
            headline: L("Pusty dzień"),
            body: L("Wpiszmy choć jeden posiłek — nie chcemy stracić serii."),
            actionTitle: L("Add meal"),
            actionKind: .openScanner
        )
    }

    private static func welcome(_ context: CoachContext) -> CoachInsight {
        CoachInsight(
            tone: .encouragement,
            headline: L("Spokojny dzień"),
            body: L("Everything looks healthy. Don't forget about water — it's often the simple missing puzzle piece.")
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
