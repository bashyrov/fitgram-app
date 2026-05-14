import SwiftUI
import WidgetKit

@main
struct MealgramWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreakWidget()
        CalorieRingWidget()
        WaterWidget()
        TodayMealsWidget()
    }
}
