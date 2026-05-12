import Foundation

/// Pure function: given the user's complete meal history + current streak +
/// already-earned achievement ids, returns the set of achievement ids that
/// should be granted now. Idempotent — feed identical inputs twice and the
/// second call returns an empty set.
struct AchievementEngine {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func evaluate(
        meals: [MealEntry],
        streak: Streak?,
        alreadyEarned: Set<String>,
        now: Date = Date()
    ) -> [String] {
        var unlocked: [String] = []

        let consider: (String, () -> Bool) -> Void = { id, predicate in
            guard !alreadyEarned.contains(id) else { return }
            if predicate() { unlocked.append(id) }
        }

        // Onboarding milestones — single positive sample is enough.
        consider("meal.first") { !meals.isEmpty }
        consider("scan.first") { meals.contains(where: { $0.source == .photoScan }) }
        consider("barcode.first") { meals.contains(where: { $0.source == .barcode }) }

        // Streak milestones — use longest length so backfills count.
        if let streak {
            consider("streak.7") { streak.longestLength >= 7 }
            consider("streak.30") { streak.longestLength >= 30 }
            consider("streak.100") { streak.longestLength >= 100 }
        }

        // Per-day aggregates: bucket meals by day, evaluate predicates.
        let dayBuckets = Self.groupByDay(meals, calendar: calendar)
        consider("protein.heavy") {
            dayBuckets.values.contains { entries in
                entries.reduce(0) { $0 + $1.totalProteinGrams } >= 120
            }
        }
        consider("variety.day") {
            dayBuckets.values.contains { entries in
                let kinds = Set(entries.map(\.mealType))
                return kinds.contains(.breakfast) && kinds.contains(.lunch) && kinds.contains(.dinner)
            }
        }

        _ = now  // future-dated predicates can reach for this without an API churn
        return unlocked
    }

    static func groupByDay(_ meals: [MealEntry], calendar: Calendar) -> [Date: [MealEntry]] {
        Dictionary(grouping: meals) { calendar.startOfDay(for: $0.consumedAt) }
    }
}
