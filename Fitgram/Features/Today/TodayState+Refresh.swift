import Foundation
import SwiftData

extension TodayState {
    /// One day's meals (newest first) and their summed macros.
    struct MealSnapshot {
        let meals: [MealEntry]
        let totals: Totals

        static func fetch(day: Date, calendar: Calendar, in context: ModelContext) throws -> MealSnapshot {
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return MealSnapshot(meals: [], totals: Totals())
            }
            let descriptor = FetchDescriptor<MealEntry>(
                predicate: #Predicate { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd },
                sortBy: [SortDescriptor(\MealEntry.consumedAt, order: .reverse)]
            )
            let meals = try context.fetch(descriptor)
            let totals = meals.reduce(into: Totals()) { acc, entry in
                acc.calories += entry.totalCaloriesKcal
                acc.protein += entry.totalProteinGrams
                acc.carbs += entry.totalCarbsGrams
                acc.fat += entry.totalFatGrams
            }
            return MealSnapshot(meals: meals, totals: totals)
        }
    }

    /// Everything one `refresh` read, applied to the state in one animation.
    struct RefreshResult {
        let meals: [MealEntry]
        let totals: Totals
        let streak: Streak
        let suggestedRecipe: Recipe?
        let upcomingEvent: CulturalEventService.Upcoming?
        let coachInsights: [CoachInsight]
        let dailyOlaPlan: DailyOlaPlan?
        let waterTotalMl: Int
        let workouts: [WorkoutEntry]
        let workoutCaloriesBurned: Double
        let workoutCaloriesCountedTowardGoal: Double
    }
}
