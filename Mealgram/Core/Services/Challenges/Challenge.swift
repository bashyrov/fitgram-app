import Foundation

/// One weekly mini-goal. Auto-rolls every ISO week — no join state, just
/// a running tally computed from the user's meal log. Catalog is static
/// today; phase-4 future expansion can move it server-side.
struct Challenge: Equatable, Sendable, Identifiable {
    enum Rule: Equatable, Sendable {
        /// Logged at least one meal on N distinct days this week.
        case loggedDays(target: Int)
        /// Hit protein goal (≥ 90 %) on N distinct days.
        case proteinDaysHit(target: Int)
        /// Within ±15 % of the calorie goal on N distinct days.
        case calorieDaysOnTarget(target: Int)
        /// Logged at least one breakfast (mealType == .breakfast) on N distinct days.
        case breakfastDays(target: Int)
        /// Distinct food-item names this week.
        case distinctFoods(target: Int)
        /// Cooked any recipe at least N times this week (uses
        /// `MealSource == .recipe`).
        case recipeCooks(target: Int)

        var target: Int {
            switch self {
            case .loggedDays(let target), .proteinDaysHit(let target),
                .calorieDaysOnTarget(let target), .breakfastDays(let target),
                .distinctFoods(let target), .recipeCooks(let target):
                return target
            }
        }
    }

    let id: String
    let title: String
    let body: String
    let systemImage: String
    let rule: Rule
}

/// Materialised progress for a single challenge in the current week.
struct ChallengeProgress: Equatable, Sendable, Identifiable {
    var id: String { challenge.id }
    let challenge: Challenge
    let current: Int
    var ratio: Double {
        guard challenge.rule.target > 0 else { return 0 }
        return min(1.0, Double(current) / Double(challenge.rule.target))
    }
    var isCompleted: Bool { current >= challenge.rule.target }
}
