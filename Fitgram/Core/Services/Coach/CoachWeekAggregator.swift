import Foundation
import SwiftData

/// Rolls the user's personal 7-day window (anchored on their sign-up day)
/// into the `CoachContext.Week` snapshot the coach reads.
@MainActor
struct CoachWeekAggregator {
    let container: ModelContainer
    let calendar: Calendar
    let now: () -> Date
    let activityCaloriePolicyStore: ActivityCaloriePolicyStore

    func aggregate(
        userRemoteID: String,
        registeredAt: Date,
        calorieGoal: Int,
        proteinGoal: Int
    ) -> CoachContext.Week {
        let context = ModelContext(container)
        let today = calendar.startOfDay(for: now())
        let weekStart = personalWeekStart(registeredAt: registeredAt, today: today)
        guard let windowEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
        else {
            return CoachContext.Week(
                startAt: today, endAt: today,
                dailyCalorieAverages: [], dailyProteinAverages: [], dailyWaterMl: [],
                workoutCalories: [], workoutMinutes: [], frequentFoods: [],
                daysWithAnyEntry: 0, daysHittingProteinGoal: 0, daysWithinCalorieGoal: 0,
                bestCalorieDayOffset: nil, weakestProteinDayOffset: nil
            )
        }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { $0.consumedAt >= weekStart && $0.consumedAt < windowEnd }
        )
        let meals = MealTotals(entries: (try? context.fetch(descriptor)) ?? [], calendar: calendar)
        let water = fetchWaterEntries(context: context, userRemoteID: userRemoteID, from: weekStart, to: windowEnd)
        let workouts = WorkoutTotals(
            workouts: fetchWorkouts(context: context, userRemoteID: userRemoteID, from: weekStart, to: windowEnd),
            calendar: calendar
        )
        var waterByDay: [Date: Int] = [:]
        for entry in water {
            waterByDay[calendar.startOfDay(for: entry.recordedAt), default: 0] += entry.milliliters
        }

        var series = DailySeries()
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { continue }
            let key = calendar.startOfDay(for: day)
            let goalForDay =
                calorieGoal
                + (activityCaloriePolicyStore.includesActivityCalories(on: key, now: now())
                    ? Int((workouts.countedCaloriesByDay[key] ?? 0).rounded())
                    : 0)
            series.append(
                kcal: meals.caloriesByDay[key] ?? 0,
                protein: meals.proteinByDay[key] ?? 0,
                water: waterByDay[key] ?? 0,
                workoutCalories: workouts.caloriesByDay[key] ?? 0,
                workoutMinutes: workouts.minutesByDay[key] ?? 0
            )
            series.countHits(proteinGoal: proteinGoal, calorieGoalForDay: goalForDay)
        }

        return CoachContext.Week(
            startAt: weekStart,
            endAt: windowEnd,
            dailyCalorieAverages: series.calories,
            dailyProteinAverages: series.protein,
            dailyWaterMl: series.water,
            workoutCalories: series.workoutCalories,
            workoutMinutes: series.workoutMinutes,
            frequentFoods: meals.frequentFoods,
            daysWithAnyEntry: series.daysWithEntry,
            daysHittingProteinGoal: series.daysProteinHit,
            daysWithinCalorieGoal: series.daysCalorieHit,
            bestCalorieDayOffset: series.bestCalorieDayOffset(calorieGoal: calorieGoal),
            weakestProteinDayOffset: series.weakestProteinDayOffset
        )
    }

    private func personalWeekStart(registeredAt: Date, today: Date) -> Date {
        let anchor = calendar.startOfDay(for: registeredAt)
        let days = calendar.dateComponents([.day], from: anchor, to: today).day ?? 0
        let cycleOffset = max(0, days) / 7 * 7
        return calendar.date(byAdding: .day, value: cycleOffset, to: anchor) ?? today
    }

    private func fetchWaterEntries(
        context: ModelContext,
        userRemoteID: String,
        from start: Date,
        to end: Date
    ) -> [WaterEntry] {
        let descriptor = FetchDescriptor<WaterEntry>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.recordedAt >= start && $0.recordedAt < end
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func fetchWorkouts(
        context: ModelContext,
        userRemoteID: String,
        from start: Date,
        to end: Date
    ) -> [WorkoutEntry] {
        let descriptor = FetchDescriptor<WorkoutEntry>(
            predicate: #Predicate {
                $0.userRemoteID == userRemoteID && $0.recordedAt >= start && $0.recordedAt < end
            }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

/// Meal calories / protein per day plus the most-logged food names.
private struct MealTotals {
    var caloriesByDay: [Date: Double] = [:]
    var proteinByDay: [Date: Double] = [:]
    let frequentFoods: [String]

    init(entries: [MealEntry], calendar: Calendar) {
        var foodCounts: [String: Int] = [:]
        for entry in entries {
            let key = calendar.startOfDay(for: entry.consumedAt)
            caloriesByDay[key, default: 0] += entry.totalCaloriesKcal
            proteinByDay[key, default: 0] += entry.totalProteinGrams
            for item in entry.items {
                let name = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty {
                    foodCounts[name, default: 0] += 1
                }
            }
        }
        frequentFoods =
            foodCounts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map(\.key)
    }
}

/// Workout burn per day, split into all calories and the ones that count
/// toward the daily goal.
private struct WorkoutTotals {
    var caloriesByDay: [Date: Double] = [:]
    var countedCaloriesByDay: [Date: Double] = [:]
    var minutesByDay: [Date: Int] = [:]

    init(workouts: [WorkoutEntry], calendar: Calendar) {
        for workout in workouts {
            let key = calendar.startOfDay(for: workout.recordedAt)
            caloriesByDay[key, default: 0] += workout.caloriesBurnedKcal
            if workout.countsTowardDailyGoal {
                countedCaloriesByDay[key, default: 0] += workout.caloriesBurnedKcal
            }
            minutesByDay[key, default: 0] += workout.durationMinutes
        }
    }
}

/// Seven per-day columns plus the hit counters derived from them.
private struct DailySeries {
    var calories: [Double] = []
    var protein: [Double] = []
    var water: [Int] = []
    var workoutCalories: [Double] = []
    var workoutMinutes: [Int] = []
    var daysWithEntry = 0
    var daysProteinHit = 0
    var daysCalorieHit = 0

    mutating func append(kcal: Double, protein: Double, water: Int, workoutCalories: Double, workoutMinutes: Int) {
        calories.append(kcal)
        self.protein.append(protein)
        self.water.append(water)
        self.workoutCalories.append(workoutCalories)
        self.workoutMinutes.append(workoutMinutes)
    }

    /// Scores the most recently appended day.
    mutating func countHits(proteinGoal: Int, calorieGoalForDay: Int) {
        let kcal = calories.last ?? 0
        let dayProtein = protein.last ?? 0
        if kcal > 0 { daysWithEntry += 1 }
        if proteinGoal > 0, dayProtein >= Double(proteinGoal) * 0.9 { daysProteinHit += 1 }
        if calorieGoalForDay > 0 {
            let ratio = kcal / Double(calorieGoalForDay)
            if ratio >= 0.85, ratio <= 1.15 { daysCalorieHit += 1 }
        }
    }

    func bestCalorieDayOffset(calorieGoal: Int) -> Int? {
        calories.enumerated()
            .filter { $0.element > 0 && calorieGoal > 0 }
            .min { abs($0.element - Double(calorieGoal)) < abs($1.element - Double(calorieGoal)) }?
            .offset
    }

    var weakestProteinDayOffset: Int? {
        protein.enumerated()
            .filter { calories.indices.contains($0.offset) && calories[$0.offset] > 0 }
            .min { $0.element < $1.element }?
            .offset
    }
}
