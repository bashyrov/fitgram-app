import Foundation

/// Weekly snapshot Ola hands back when the user opens the "Co u Ciebie"
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
    static func from(context: CoachContext, generator: any CoachInsightGenerator, now: Date) -> WeeklyDebrief {
        let insights = generator.generate(for: context)
        return WeeklyDebrief(
            generatedAt: now,
            headline: headline(for: context),
            stats: stats(for: context),
            insights: insights
        )
    }

    private static func headline(for context: CoachContext) -> String {
        switch context.week.daysWithinCalorieGoal {
        case 6...:
            return String(localized: "Cudowny tydzień")
        case 4...5:
            return String(localized: "Solidny tydzień")
        case 2...3:
            return String(localized: "Mieszany tydzień")
        default:
            return String(localized: "Spróbujmy łapać rytm")
        }
    }

    private static func stats(for context: CoachContext) -> [Stat] {
        let calorieAvg = average(context.week.dailyCalorieAverages)
        let proteinCaption = String(localized: "z 7 dni w celu białka")
        let calorieCaption = String(localized: "z 7 dni w celu kalorii")
        return [
            Stat(
                kind: .avgCalories,
                value: "\(Int(calorieAvg)) kcal",
                caption: String(localized: "średnio dziennie")
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
                caption: String(localized: "dni z wpisem")
            ),
            Stat(
                kind: .currentStreak,
                value: "\(context.streak.current)",
                caption: String(localized: "dzień serii")
            ),
        ]
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
}
