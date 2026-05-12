import Foundation

/// Pure function. Given the meals for the current ISO week and the
/// user's goals, returns how far along every catalog challenge is. Kept
/// separate from SwiftData reads so the rules are trivially unit-tested.
struct ChallengeEvaluator {
    struct Input: Sendable {
        var meals: [MealEntry]
        var calorieGoal: Int
        var proteinGoal: Int
        var calendar: Calendar
    }

    static func evaluate(_ challenges: [Challenge], with input: Input) -> [ChallengeProgress] {
        challenges.map { challenge in
            ChallengeProgress(
                challenge: challenge,
                current: progress(for: challenge, input: input)
            )
        }
    }

    static func progress(for challenge: Challenge, input: Input) -> Int {
        switch challenge.rule {
        case .loggedDays:
            return distinctDays(in: input.meals, calendar: input.calendar)
        case .proteinDaysHit:
            return daysHittingProtein(input)
        case .calorieDaysOnTarget:
            return daysWithinCalorieBand(input)
        case .breakfastDays:
            return distinctBreakfastDays(input)
        case .distinctFoods:
            return distinctFoodNames(input.meals)
        case .recipeCooks:
            return input.meals.filter { $0.source == .recipe }.count
        }
    }

    // MARK: - Helpers

    private static func distinctDays(in meals: [MealEntry], calendar: Calendar) -> Int {
        Set(meals.map { calendar.startOfDay(for: $0.consumedAt) }).count
    }

    private static func daysHittingProtein(_ input: Input) -> Int {
        guard input.proteinGoal > 0 else { return 0 }
        let byDay = groupByDay(input.meals, calendar: input.calendar)
        let threshold = Double(input.proteinGoal) * 0.9
        return byDay.values.filter { $0.totalProtein >= threshold }.count
    }

    private static func daysWithinCalorieBand(_ input: Input) -> Int {
        guard input.calorieGoal > 0 else { return 0 }
        let byDay = groupByDay(input.meals, calendar: input.calendar)
        let lower = Double(input.calorieGoal) * 0.85
        let upper = Double(input.calorieGoal) * 1.15
        return byDay.values.filter { $0.totalCalories >= lower && $0.totalCalories <= upper }.count
    }

    private static func distinctBreakfastDays(_ input: Input) -> Int {
        let calendar = input.calendar
        let days = input.meals
            .filter { $0.mealType == .breakfast }
            .map { calendar.startOfDay(for: $0.consumedAt) }
        return Set(days).count
    }

    private static func distinctFoodNames(_ meals: [MealEntry]) -> Int {
        Set(meals.flatMap { $0.items }.map { $0.name.lowercased() }).count
    }

    // MARK: - DayBucket helper

    private struct DayBucket {
        var totalCalories: Double = 0
        var totalProtein: Double = 0
    }

    private static func groupByDay(_ meals: [MealEntry], calendar: Calendar) -> [Date: DayBucket] {
        var byDay: [Date: DayBucket] = [:]
        for meal in meals {
            let key = calendar.startOfDay(for: meal.consumedAt)
            var bucket = byDay[key, default: DayBucket()]
            bucket.totalCalories += meal.totalCaloriesKcal
            bucket.totalProtein += meal.totalProteinGrams
            byDay[key] = bucket
        }
        return byDay
    }
}
