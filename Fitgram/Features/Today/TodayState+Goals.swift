import Foundation

// Daily calorie + macro goals for the visible day, after per-day
// overrides and (optionally) workout calories.
extension TodayState {
    var calorieGoal: Int {
        baseCalorieGoal + Int(workoutCaloriesAppliedToGoal.rounded())
    }

    var baseCalorieGoal: Int {
        guard let user else { return 2100 }
        return calorieOverrideStore.value(for: user.remoteID, on: viewingDate) ?? user.dailyCalorieGoalKcal
    }

    var includesActivityCaloriesInGoal: Bool {
        activityCaloriePolicyStore.includesActivityCalories(on: viewingDate, now: now())
    }

    var workoutCaloriesAppliedToGoal: Double {
        includesActivityCaloriesInGoal ? workoutCaloriesCountedTowardGoal : 0
    }

    var proteinGoal: Int { macroGoals.protein }
    var carbsGoal: Int { macroGoals.carbs }
    var fatGoal: Int { macroGoals.fat }

    private var macroGoals: DailyMacroGoals {
        guard let user else {
            return DailyMacroGoals(protein: 120, carbs: 240, fat: 70)
        }
        if let override = macroOverrideStore.value(for: user.remoteID, on: viewingDate) {
            return override
        }
        if user.macrosOverridden {
            let base = max(1, baseCalorieGoal)
            let ratio = max(0.25, min(2.5, Double(calorieGoal) / Double(base)))
            return DailyMacroGoals(
                protein: Int((Double(user.proteinGoalGrams) * ratio).rounded()),
                carbs: Int((Double(user.carbsGoalGrams) * ratio).rounded()),
                fat: Int((Double(user.fatGoalGrams) * ratio).rounded())
            )
        }
        let split = GoalCalculator.macroSplit(for: user.goalKind, preset: user.dietMacroPreset)
        let calories = Double(max(0, calorieGoal))
        return DailyMacroGoals(
            protein: Int(((calories * split.protein) / 4).rounded()),
            carbs: Int(((calories * split.carbs) / 4).rounded()),
            fat: Int(((calories * split.fat) / 9).rounded())
        )
    }

    var calorieRemaining: Int {
        max(0, calorieGoal - Int(totals.calories))
    }
    var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(1.0, totals.calories / Double(calorieGoal))
    }
}
