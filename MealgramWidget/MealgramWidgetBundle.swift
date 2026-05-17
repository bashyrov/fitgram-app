import SwiftUI
import WidgetKit

@main
struct MealgramWidgetBundle: WidgetBundle {
    // Order matters: iOS preselects the first widget in the "Add Widget"
    // gallery, so we lead with the calorie-and-macro snapshot since
    // that's what users actually want to see at a glance for today.
    // The Live Activity isn't a Home Screen widget — it just needs to
    // live inside the bundle so iOS knows about its content + Dynamic
    // Island layouts.
    var body: some Widget {
        CalorieRingWidget()
        TodayMealsWidget()
        WaterWidget()
        StreakWidget()
        MealgramLiveActivity()
    }
}
