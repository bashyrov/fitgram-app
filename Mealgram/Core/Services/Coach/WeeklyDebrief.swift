import Foundation

/// Weekly snapshot Ola hands back when the user opens the "How you're doing"
/// sheet from Today. Combines the same `CoachInsight` engine output with
/// derived stats so the view doesn't have to do arithmetic.
enum WeeklyDebriefStatKind: String, Sendable {
    case avgCalories
    case proteinDaysHit
    case calorieDaysOnTarget
    case daysLogged
    case currentStreak
}

struct WeeklyDebrief: Equatable, Sendable {
    struct Stat: Equatable, Sendable, Identifiable {
        var id: WeeklyDebriefStatKind { kind }
        let kind: WeeklyDebriefStatKind
        let value: String
        let caption: String
    }

    let generatedAt: Date
    let headline: String
    let stats: [Stat]
    let insights: [CoachInsight]
}

extension WeeklyDebrief {
    static func from(
        context: CoachContext,
        generator: any CoachInsightGenerator,
        now: Date
    ) async -> WeeklyDebrief {
        let aiResult = await generator.generateWeekly(for: context)
        return WeeklyDebrief(
            generatedAt: now,
            headline: aiResult.headline ?? headline(for: context),
            stats: stats(for: context),
            insights: aiResult.insights
        )
    }

    private static func headline(for context: CoachContext) -> String {
        switch context.week.daysWithinCalorieGoal {
        case 6...:
            return L("Wonderful week")
        case 4...5:
            return L("Solid week")
        case 2...3:
            return L("Mixed week")
        default:
            return L("Let's catch the rhythm")
        }
    }

    private static func stats(for context: CoachContext) -> [Stat] {
        let calorieAvg = average(context.week.dailyCalorieAverages)
        let proteinCaption = L("of 7 days hitting protein")
        let calorieCaption = L("of 7 days in calorie target")
        return [
            Stat(
                kind: .avgCalories,
                value: "\(Int(calorieAvg)) kcal",
                caption: L("średnio dziennie")
            ),
            Stat(
                kind: .calorieDaysOnTarget,
                value: "\(context.week.daysWithinCalorieGoal)",
                caption: calorieCaption
            ),
            Stat(
                kind: .proteinDaysHit,
                value: "\(context.week.daysHittingProteinGoal)",
                caption: proteinCaption
            ),
            Stat(
                kind: .daysLogged,
                value: "\(context.week.daysWithAnyEntry)",
                caption: L("days with entries")
            ),
            Stat(
                kind: .currentStreak,
                value: "\(context.streak.current)",
                caption: L("day of streak")
            ),
        ]
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
