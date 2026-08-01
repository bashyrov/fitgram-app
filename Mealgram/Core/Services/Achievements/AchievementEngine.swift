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

    /// Extra context the catalog needs beyond the meal log + streak. Each
    /// field is optional so non-meal predicates can be skipped when the
    /// data isn't available yet (tests, first launch).
    struct Inputs: Sendable {
        var proteinGoalGrams: Int?
        var carbsGoalGrams: Int?
        var fatGoalGrams: Int?
        var calorieGoalKcal: Int?
        /// `true` once the user has logged at least one weight entry.
        var hasLoggedWeight: Bool
        /// Total recipe.cookCount sum across the library.
        var totalRecipeCooks: Int
        /// Total WeightEntry rows on file.
        var totalWeightEntries: Int
        /// How many achievement rows already on file. Used by the meta
        /// `achievements.ten` predicate without re-counting.
        var totalAchievementsEarned: Int

        static let empty = Inputs(
            proteinGoalGrams: nil, carbsGoalGrams: nil, fatGoalGrams: nil,
            calorieGoalKcal: nil,
            hasLoggedWeight: false,
            totalRecipeCooks: 0, totalWeightEntries: 0,
            totalAchievementsEarned: 0
        )
    }

    // swiftlint:disable function_body_length
    func evaluate(
        meals: [MealEntry],
        streak: Streak?,
        alreadyEarned: Set<String>,
        inputs: Inputs = .empty,
        now: Date = Date()
    ) -> [String] {
        var unlocked: [String] = []

        let consider: (String, () -> Bool) -> Void = { id, predicate in
            guard !alreadyEarned.contains(id) else { return }
            if predicate() { unlocked.append(id) }
        }

        // Onboarding milestones — single positive sample is enough.
        let totalMeals = meals.count
        consider("meal.first") { !meals.isEmpty }
        consider("scan.first") { meals.contains(where: { $0.source == .photoScan }) }
        consider("barcode.first") { meals.contains(where: { $0.source == .barcode }) }
        consider("recipe.first") { meals.contains(where: { $0.source == .recipe }) }
        consider("voice.first") { meals.contains(where: { $0.source == .voice }) }
        consider("quickdb.first") { meals.contains(where: { $0.source == .quickDatabase }) }
        consider("weight.tracked") { inputs.hasLoggedWeight }

        for threshold in [5, 10, 25, 50, 100, 250, 500, 1000, 2000, 5000] {
            consider("meal.count.\(threshold)") { totalMeals >= threshold }
        }

        for source in MealSource.allCases {
            let count = meals.filter { $0.source == source }.count
            for threshold in [5, 25, 100, 250] {
                consider("source.\(source.achievementSlug).\(threshold)") { count >= threshold }
            }
        }

        for mealType in MealType.allCases {
            let count = meals.filter { $0.mealType == mealType }.count
            for threshold in [3, 7, 30, 100, 250] {
                consider("mealtype.\(mealType.rawValue).\(threshold)") { count >= threshold }
            }
        }

        // Streak milestones — use longest length so backfills count.
        if let streak {
            consider("streak.3") { streak.longestLength >= 3 }
            consider("streak.7") { streak.longestLength >= 7 }
            consider("streak.14") { streak.longestLength >= 14 }
            consider("streak.30") { streak.longestLength >= 30 }
            consider("streak.50") { streak.longestLength >= 50 }
            consider("streak.60") { streak.longestLength >= 60 }
            consider("streak.100") { streak.longestLength >= 100 }
            consider("streak.200") { streak.longestLength >= 200 }
            consider("streak.365") { streak.longestLength >= 365 }
            consider("streak.500") { streak.longestLength >= 500 }
            consider("streak.730") { streak.longestLength >= 730 }
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
        let varietyDayCount = dayBuckets.values.filter { entries in
            let kinds = Set(entries.map(\.mealType))
            return kinds.contains(.breakfast) && kinds.contains(.lunch) && kinds.contains(.dinner)
        }.count
        for threshold in [3, 10, 30, 100] {
            consider("variety.days.\(threshold)") { varietyDayCount >= threshold }
        }
        consider("macros.balanced") {
            guard let proteinGoal = inputs.proteinGoalGrams,
                let carbsGoal = inputs.carbsGoalGrams,
                let fatGoal = inputs.fatGoalGrams,
                proteinGoal > 0, carbsGoal > 0, fatGoal > 0
            else { return false }
            return dayBuckets.values.contains { entries in
                let protein = entries.reduce(0) { $0 + $1.totalProteinGrams }
                let carbs = entries.reduce(0) { $0 + $1.totalCarbsGrams }
                let fat = entries.reduce(0) { $0 + $1.totalFatGrams }
                return Self.within(protein, of: Double(proteinGoal), tolerance: 0.10)
                    && Self.within(carbs, of: Double(carbsGoal), tolerance: 0.10)
                    && Self.within(fat, of: Double(fatGoal), tolerance: 0.10)
            }
        }
        if let calorieGoal = inputs.calorieGoalKcal, calorieGoal > 0 {
            let targetDays = dayBuckets.values.filter { entries in
                let calories = entries.reduce(0) { $0 + $1.totalCaloriesKcal }
                return Self.within(calories, of: Double(calorieGoal), tolerance: 0.10)
            }.count
            for threshold in [3, 7, 14, 30, 60, 100] {
                consider("calories.target.days.\(threshold)") { targetDays >= threshold }
            }
        }
        consider("week.consistent") {
            let days = Set(meals.map { calendar.startOfDay(for: $0.consumedAt) }).sorted()
            return Self.longestConsecutiveRun(days: days, calendar: calendar) >= 7
        }
        if let proteinGoal = inputs.proteinGoalGrams, proteinGoal > 0 {
            let threshold = Double(proteinGoal) * 0.9
            let proteinDays = dayBuckets.values.filter { entries in
                entries.reduce(0) { $0 + $1.totalProteinGrams } >= threshold
            }.count
            for dayThreshold in [3, 14, 30, 100, 250] {
                consider("protein.days.\(dayThreshold)") { proteinDays >= dayThreshold }
            }
        }
        consider("protein.week") {
            guard let proteinGoal = inputs.proteinGoalGrams, proteinGoal > 0 else { return false }
            let threshold = Double(proteinGoal) * 0.9
            let hitDays = Set(
                dayBuckets.compactMap { day, entries -> Date? in
                    let total = entries.reduce(0) { $0 + $1.totalProteinGrams }
                    return total >= threshold ? day : nil
                }
            ).sorted()
            return Self.longestConsecutiveRun(days: hitDays, calendar: calendar) >= 7
        }
        consider("recipes.ten") { inputs.totalRecipeCooks >= 10 }
        for threshold in [3, 25, 50, 100] {
            consider("recipes.cooked.\(threshold)") { inputs.totalRecipeCooks >= threshold }
        }
        consider("weight.ten") { inputs.totalWeightEntries >= 10 }
        for threshold in [3, 25, 50, 100] {
            consider("weight.entries.\(threshold)") { inputs.totalWeightEntries >= threshold }
        }
        consider("tag.first") { meals.contains { !$0.tags.isEmpty } }
        let tagCount = meals.reduce(0) { $0 + $1.tags.count }
        for threshold in [5, 25, 100, 250] {
            consider("tags.used.\(threshold)") { tagCount >= threshold }
        }
        // The meta achievement fires when the user is *about* to cross
        // their 10th badge — already-earned set includes everything that
        // unlocked in this very call, so we add the pending count.
        consider("achievements.ten") {
            inputs.totalAchievementsEarned + unlocked.count >= 10
        }
        for threshold in [25, 50, 75, 100] {
            consider("achievements.\(threshold)") {
                inputs.totalAchievementsEarned + unlocked.count >= threshold
            }
        }

        _ = now  // future-dated predicates can reach for this without an API churn
        return unlocked
    }
    // swiftlint:enable function_body_length

    private static func within(_ value: Double, of target: Double, tolerance: Double) -> Bool {
        guard target > 0 else { return false }
        let ratio = abs(value - target) / target
        return ratio <= tolerance
    }

    private static func longestConsecutiveRun(days: [Date], calendar: Calendar) -> Int {
        guard !days.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<days.count {
            let gap = calendar.dateComponents([.day], from: days[index - 1], to: days[index]).day ?? 0
            if gap == 1 {
                current += 1
                best = max(best, current)
            } else if gap > 1 {
                current = 1
            }
        }
        return best
    }

    static func groupByDay(_ meals: [MealEntry], calendar: Calendar) -> [Date: [MealEntry]] {
        Dictionary(grouping: meals) { calendar.startOfDay(for: $0.consumedAt) }
    }
}

private extension MealSource {
    var achievementSlug: String {
        switch self {
        case .photoScan: return "photo"
        case .recipe: return "recipe"
        case .quickDatabase: return "quickdb"
        case .voice: return "voice"
        case .barcode: return "barcode"
        case .manual: return "manual"
        }
    }
}
