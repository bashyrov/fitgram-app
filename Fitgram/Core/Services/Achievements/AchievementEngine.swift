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
        /// Non-meal counters for leveled tracks and special badges (water,
        /// workouts, friends, …). Missing keys count as 0.
        var counters: [AchievementMetric: Int] = [:]

        static let empty = Inputs(
            proteinGoalGrams: nil, carbsGoalGrams: nil, fatGoalGrams: nil,
            calorieGoalKcal: nil,
            hasLoggedWeight: false,
            totalRecipeCooks: 0, totalWeightEntries: 0,
            totalAchievementsEarned: 0
        )
    }

    func evaluate(
        meals: [MealEntry],
        streak: Streak?,
        alreadyEarned: Set<String>,
        inputs: Inputs = .empty,
        now: Date = Date()
    ) -> [String] {
        evaluate(
            facts: meals.map(MealFacts.init), streak: streak, alreadyEarned: alreadyEarned, inputs: inputs, now: now)
    }

    /// Same as `evaluate(meals:…)` over plain snapshots. SwiftData property
    /// access is slow, so callers read each meal once and reuse the facts.
    func evaluate(
        facts meals: [MealFacts],
        streak: Streak?,
        alreadyEarned: Set<String>,
        inputs: Inputs = .empty,
        now: Date = Date()
    ) -> [String] {
        // Order matters: unlocks are reported in evaluation order and the
        // meta badges count everything unlocked earlier in this call.
        let collector = UnlockCollector(alreadyEarned: alreadyEarned)
        let dayBuckets = Self.groupByDay(meals, calendar: calendar)
        considerEntryMilestones(meals, inputs: inputs, collector: collector)
        if let streak {
            considerStreakMilestones(streak, collector: collector)
        }
        considerDailyMilestones(dayBuckets, inputs: inputs, collector: collector)
        considerConsistencyMilestones(meals, dayBuckets: dayBuckets, inputs: inputs, collector: collector)
        considerLifetimeMilestones(meals, inputs: inputs, collector: collector)
        let metrics = Self.metrics(meals: meals, dayBuckets: dayBuckets, inputs: inputs, calendar: calendar, now: now)
        considerTrackMilestones(metrics, collector: collector)
        considerSpecialMilestones(meals, dayBuckets: dayBuckets, metrics: metrics, collector: collector)
        considerMetaMilestones(inputs: inputs, collector: collector)
        return collector.unlocked
    }

    /// Collects unlock ids in evaluation order, skipping ones already earned.
    private final class UnlockCollector {
        private let alreadyEarned: Set<String>
        private(set) var unlocked: [String] = []

        init(alreadyEarned: Set<String>) {
            self.alreadyEarned = alreadyEarned
        }

        func consider(_ id: String, _ predicate: () -> Bool) {
            guard !alreadyEarned.contains(id) else { return }
            if predicate() { unlocked.append(id) }
        }
    }

    private func considerEntryMilestones(_ meals: [MealFacts], inputs: Inputs, collector: UnlockCollector) {
        // Onboarding milestones — single positive sample is enough.
        let totalMeals = meals.count
        collector.consider("meal.first") { !meals.isEmpty }
        collector.consider("scan.first") { meals.contains(where: { $0.source == .photoScan }) }
        collector.consider("barcode.first") { meals.contains(where: { $0.source == .barcode }) }
        collector.consider("recipe.first") { meals.contains(where: { $0.source == .recipe }) }
        collector.consider("voice.first") { meals.contains(where: { $0.source == .voice }) }
        collector.consider("quickdb.first") { meals.contains(where: { $0.source == .quickDatabase }) }
        collector.consider("weight.tracked") { inputs.hasLoggedWeight }

        for threshold in [5, 10, 25, 50, 100, 250, 500, 1000, 2000, 5000] {
            collector.consider("meal.count.\(threshold)") { totalMeals >= threshold }
        }

        for source in MealSource.allCases {
            let count = meals.filter { $0.source == source }.count
            for threshold in [5, 25, 100, 250] {
                collector.consider("source.\(source.achievementSlug).\(threshold)") { count >= threshold }
            }
        }

        for mealType in MealType.allCases {
            let count = meals.filter { $0.mealType == mealType }.count
            for threshold in [3, 7, 30, 100, 250] {
                collector.consider("mealtype.\(mealType.rawValue).\(threshold)") { count >= threshold }
            }
        }
    }

    private func considerStreakMilestones(_ streak: Streak, collector: UnlockCollector) {
        // Streak milestones — use longest length so backfills count.
        collector.consider("streak.3") { streak.longestLength >= 3 }
        collector.consider("streak.7") { streak.longestLength >= 7 }
        collector.consider("streak.14") { streak.longestLength >= 14 }
        collector.consider("streak.30") { streak.longestLength >= 30 }
        collector.consider("streak.50") { streak.longestLength >= 50 }
        collector.consider("streak.60") { streak.longestLength >= 60 }
        collector.consider("streak.100") { streak.longestLength >= 100 }
        collector.consider("streak.200") { streak.longestLength >= 200 }
        collector.consider("streak.365") { streak.longestLength >= 365 }
        collector.consider("streak.500") { streak.longestLength >= 500 }
        collector.consider("streak.730") { streak.longestLength >= 730 }
    }

    private func considerDailyMilestones(
        _ dayBuckets: [Date: [MealFacts]],
        inputs: Inputs,
        collector: UnlockCollector
    ) {
        // Per-day aggregates: bucket meals by day, evaluate predicates.
        collector.consider("protein.heavy") {
            dayBuckets.values.contains { entries in
                entries.reduce(0) { $0 + $1.totalProteinGrams } >= 120
            }
        }
        collector.consider("variety.day") {
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
            collector.consider("variety.days.\(threshold)") { varietyDayCount >= threshold }
        }
        collector.consider("macros.balanced") {
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
                collector.consider("calories.target.days.\(threshold)") { targetDays >= threshold }
            }
        }
    }

    private func considerConsistencyMilestones(
        _ meals: [MealFacts],
        dayBuckets: [Date: [MealFacts]],
        inputs: Inputs,
        collector: UnlockCollector
    ) {
        collector.consider("week.consistent") {
            let days = Set(meals.map { calendar.startOfDay(for: $0.consumedAt) }).sorted()
            return Self.longestConsecutiveRun(days: days, calendar: calendar) >= 7
        }
        if let proteinGoal = inputs.proteinGoalGrams, proteinGoal > 0 {
            let threshold = Double(proteinGoal) * 0.9
            let proteinDays = dayBuckets.values.filter { entries in
                entries.reduce(0) { $0 + $1.totalProteinGrams } >= threshold
            }.count
            for dayThreshold in [3, 14, 30, 100, 250] {
                collector.consider("protein.days.\(dayThreshold)") { proteinDays >= dayThreshold }
            }
        }
        collector.consider("protein.week") {
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
    }

    private func considerLifetimeMilestones(_ meals: [MealFacts], inputs: Inputs, collector: UnlockCollector) {
        collector.consider("recipes.ten") { inputs.totalRecipeCooks >= 10 }
        for threshold in [3, 25, 50, 100] {
            collector.consider("recipes.cooked.\(threshold)") { inputs.totalRecipeCooks >= threshold }
        }
        collector.consider("weight.ten") { inputs.totalWeightEntries >= 10 }
        for threshold in [3, 25, 50, 100] {
            collector.consider("weight.entries.\(threshold)") { inputs.totalWeightEntries >= threshold }
        }
        collector.consider("tag.first") { meals.contains { !$0.tags.isEmpty } }
        let tagCount = meals.reduce(0) { $0 + $1.tags.count }
        for threshold in [5, 25, 100, 250] {
            collector.consider("tags.used.\(threshold)") { tagCount >= threshold }
        }
    }

    private func considerMetaMilestones(inputs: Inputs, collector: UnlockCollector) {
        // The meta achievement fires when the user is *about* to cross
        // their 10th badge — already-earned set includes everything that
        // unlocked in this very call, so we add the pending count.
        collector.consider("achievements.ten") {
            inputs.totalAchievementsEarned + collector.unlocked.count >= 10
        }
        for threshold in [25, 50, 75, 100, 150, 200, 250, 300] {
            collector.consider("achievements.\(threshold)") {
                inputs.totalAchievementsEarned + collector.unlocked.count >= threshold
            }
        }
    }

    /// Meal-derived counters merged with the external ones from `inputs`.
    static func metrics(
        meals: [MealFacts],
        dayBuckets: [Date: [MealFacts]],
        inputs: Inputs,
        calendar: Calendar,
        now: Date
    ) -> [AchievementMetric: Int] {
        AchievementMetrics.fromMeals(
            meals, dayBuckets: dayBuckets, calorieGoalKcal: inputs.calorieGoalKcal, calendar: calendar, now: now
        ).merging(inputs.counters) { _, external in external }
    }

    private func considerTrackMilestones(_ metrics: [AchievementMetric: Int], collector: UnlockCollector) {
        for track in AchievementTracks.all {
            let value = metrics[track.metric] ?? 0
            for (index, threshold) in track.thresholds.enumerated() {
                collector.consider(track.id(level: index + 1)) { value >= threshold }
            }
        }
    }

    private func considerSpecialMilestones(
        _ meals: [MealFacts],
        dayBuckets: [Date: [MealFacts]],
        metrics: [AchievementMetric: Int],
        collector: UnlockCollector
    ) {
        let hour = { (meal: MealFacts) in calendar.component(.hour, from: meal.consumedAt) }
        collector.consider("special.night_owl") { meals.contains { hour($0) >= 23 || hour($0) < 4 } }
        collector.consider("special.early_bird") { meals.contains { $0.mealType == .breakfast && hour($0) < 7 } }
        collector.consider("special.full_weekend") {
            dayBuckets.keys.contains { day in
                calendar.component(.weekday, from: day) == 7
                    && calendar.date(byAdding: .day, value: 1, to: day).map { dayBuckets[$0] != nil } == true
            }
        }
        collector.consider("special.five_meals") { dayBuckets.values.contains { $0.count >= 5 } }
        collector.consider("special.rainbow") {
            dayBuckets.values.contains { entries in
                Set(entries.flatMap(\.itemNames).map { $0.lowercased() }).count >= 8
            }
        }
        let proteinPeak = dayBuckets.values.map { $0.reduce(0) { $0 + $1.totalProteinGrams } }.max() ?? 0
        collector.consider("special.protein_150") { proteinPeak >= 150 }
        collector.consider("special.protein_200") { proteinPeak >= 200 }
        collector.consider("special.royal_breakfast") {
            meals.contains { $0.mealType == .breakfast && $0.totalCaloriesKcal > 600 }
        }
        let waterPeak = metrics[.maxWaterDayMl] ?? 0
        collector.consider("special.hydrated_2l") { waterPeak >= 2000 }
        collector.consider("special.hydrated_3l") { waterPeak >= 3000 }
        collector.consider("special.all_methods") { Set(meals.map(\.source)).count >= MealSource.allCases.count }
        let days = dayBuckets.keys.sorted()
        collector.consider("special.comeback") {
            zip(days, days.dropFirst()).contains { previous, next in
                (calendar.dateComponents([.day], from: previous, to: next).day ?? 0) >= 8
            }
        }
        collector.consider("special.documented") {
            meals.contains { $0.photoFilename != nil && !($0.notes ?? "").isEmpty && !$0.tags.isEmpty }
        }
        collector.consider("special.full_month") { Self.hasFullMonth(days: days, calendar: calendar) }
        collector.consider("special.marathon") { (metrics[.maxWorkoutMinutes] ?? 0) >= 90 }
        for holiday in AchievementSpecials.holidays {
            collector.consider(holiday.id) {
                days.contains { day in
                    let parts = calendar.dateComponents([.month, .day], from: day)
                    return parts.month == holiday.month && holiday.days.contains(parts.day ?? 0)
                }
            }
        }
    }

    private static func hasFullMonth(days: [Date], calendar: Calendar) -> Bool {
        let byMonth = Dictionary(grouping: days) { day -> DateComponents in
            calendar.dateComponents([.year, .month], from: day)
        }
        return byMonth.contains { components, monthDays in
            guard let start = calendar.date(from: components),
                let range = calendar.range(of: .day, in: .month, for: start)
            else { return false }
            return monthDays.count >= range.count
        }
    }

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

    static func groupByDay(_ meals: [MealFacts], calendar: Calendar) -> [Date: [MealFacts]] {
        Dictionary(grouping: meals) { calendar.startOfDay(for: $0.consumedAt) }
    }
}

extension MealSource {
    fileprivate var achievementSlug: String {
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
