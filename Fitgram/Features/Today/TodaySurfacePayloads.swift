import Foundation

/// Today's numbers shaped for the surfaces outside the app: the
/// home-screen widget, the Live Activity and the Watch companion.
struct TodaySurfacePayloads {
    struct Goals {
        let calories: Int
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    let totals: TodayState.Totals
    let goals: Goals
    let waterMl: Int
    let waterGoalMl: Int
    /// Sorted by `consumedAt`, newest first.
    let meals: [MealEntry]
    let streakLength: Int
    let updatedAt: Date

    /// The Live Activity only starts once the user has logged a meal or
    /// some water.
    var hasActivityToShow: Bool {
        !meals.isEmpty || waterMl > 0
    }

    var widget: WidgetSnapshot {
        // Up to 6 most-recent meals. Prefer the meal's "primary" name
        // (first item) and round kcal to the nearest integer so the
        // widget can format without re-rounding.
        let recentMeals: [WidgetSnapshot.MealRow] = meals.prefix(6).map { entry in
            WidgetSnapshot.MealRow(
                name: entry.items.first?.name ?? L("Posiłek"),
                kcal: Int(entry.totalCaloriesKcal.rounded())
            )
        }
        return WidgetSnapshot(
            streakLength: streakLength,
            calorieGoalKcal: goals.calories,
            caloriesConsumedKcal: Int(totals.calories),
            lastMealName: meals.first?.items.first?.name ?? "",
            updatedAt: updatedAt,
            proteinConsumedGrams: Int(totals.protein.rounded()),
            proteinGoalGrams: goals.protein,
            carbsConsumedGrams: Int(totals.carbs.rounded()),
            carbsGoalGrams: goals.carbs,
            fatConsumedGrams: Int(totals.fat.rounded()),
            fatGoalGrams: goals.fat,
            waterMl: waterMl,
            waterGoalMl: waterGoalMl,
            recentMeals: recentMeals
        )
    }

    var liveActivity: FitgramActivityAttributes.ContentState {
        FitgramActivityAttributes.ContentState(
            kcalConsumed: Int(totals.calories.rounded()),
            kcalGoal: goals.calories,
            proteinConsumed: Int(totals.protein.rounded()),
            proteinGoal: goals.protein,
            carbsConsumed: Int(totals.carbs.rounded()),
            carbsGoal: goals.carbs,
            fatConsumed: Int(totals.fat.rounded()),
            fatGoal: goals.fat,
            waterMl: waterMl,
            waterGoalMl: waterGoalMl,
            updatedAt: updatedAt
        )
    }

    /// Sent as WCSession application context — "current state, replace
    /// previous" — the right primitive for a small idempotent payload.
    var watch: WatchSnapshot {
        WatchSnapshot(
            kcalConsumed: Int(totals.calories.rounded()),
            kcalGoal: goals.calories,
            proteinConsumed: Int(totals.protein.rounded()),
            proteinGoal: goals.protein,
            waterMl: waterMl,
            waterGoalMl: waterGoalMl,
            updatedAt: updatedAt
        )
    }
}
