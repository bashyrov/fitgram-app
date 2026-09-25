import AppIntents
import Foundation

/// Names for in-app notifications fired from AppIntents. Listed in one
/// place so MainTabView's observer doesn't drift from the intent side.
enum AppShortcutAction {
    static let logMeal = Notification.Name("fitgram.shortcut.logMeal")
    static let showToday = Notification.Name("fitgram.shortcut.showToday")
    static let showWeeklyDebrief = Notification.Name("fitgram.shortcut.showWeeklyDebrief")
    static let openRecipes = Notification.Name("fitgram.shortcut.openRecipes")
    /// Posted when the user taps the currently-selected tab item. Tab
    /// content listens and scrolls itself to the top — matches the
    /// platform default behaviour of iOS apps with scroll views.
    static let scrollTodayToTop = Notification.Name("fitgram.tab.scrollTodayToTop")
    /// Posted after the user saves a goal edit in Profile so observers
    /// (e.g. GoalTrackingState on Today) can refetch their snapshot
    /// without waiting for the user to re-enter the tab.
    static let mainGoalChanged = Notification.Name("fitgram.profile.mainGoalChanged")
    /// Posted when the user taps the "+1 szklanka" button in the Live
    /// Activity (Dynamic Island expanded). MainTabView observes it and
    /// routes to `TodayState.logWaterGlass` for the signed-in user —
    /// ActivityKit forbids mutating data directly from the activity
    /// view, so a deep-link bounce is the only path.
    static let addWaterFromActivity = Notification.Name("fitgram.activity.addWater")
}

/// Open the app and raise the "Add meal" action sheet.
struct LogMealIntent: AppIntent {
    static let title: LocalizedStringResource = "Add meal"
    static let description = IntentDescription("Otwiera Fitgram i pokazuje opcje dodania posiłku.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: AppShortcutAction.logMeal, object: nil)
        }
        return .result()
    }
}

/// Open the app and route to the Today tab.
struct ShowTodayIntent: AppIntent {
    static let title: LocalizedStringResource = "Pokaż dzisiejszy posiłek"
    static let description = IntentDescription("Otwiera ekran Dziś w Fitgram.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: AppShortcutAction.showToday, object: nil)
        }
        return .result()
    }
}

/// Open the app and raise the weekly debrief sheet.
struct ShowWeeklyDebriefIntent: AppIntent {
    static let title: LocalizedStringResource = "Tygodniowe podsumowanie"
    static let description = IntentDescription("Otwiera podsumowanie tygodnia od Oli.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: AppShortcutAction.showWeeklyDebrief, object: nil)
        }
        return .result()
    }
}

/// Auto-discovered by iOS. Provides the system Shortcuts app /
/// Spotlight / Siri with our three top-level shortcuts and the phrases
/// users can speak.
struct FitgramShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Add meal in \(.applicationName)",
                "Zapisz jedzenie w \(.applicationName)",
            ],
            shortTitle: "Add meal",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ShowTodayIntent(),
            phrases: [
                "Pokaż dzisiaj w \(.applicationName)",
                "What I ate today in \(.applicationName)",
            ],
            shortTitle: "Today",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: ShowWeeklyDebriefIntent(),
            phrases: [
                "Podsumowanie tygodnia w \(.applicationName)",
                "Co u mnie w \(.applicationName)",
            ],
            shortTitle: "How you're doing",
            systemImageName: "sparkles"
        )
    }
}
