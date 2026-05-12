import AppIntents
import Foundation

/// Names for in-app notifications fired from AppIntents. Listed in one
/// place so MainTabView's observer doesn't drift from the intent side.
enum AppShortcutAction {
    static let logMeal = Notification.Name("mealgram.shortcut.logMeal")
    static let showToday = Notification.Name("mealgram.shortcut.showToday")
    static let showWeeklyDebrief = Notification.Name("mealgram.shortcut.showWeeklyDebrief")
}

/// Open the app and raise the "Add meal" action sheet.
struct LogMealIntent: AppIntent {
    static var title: LocalizedStringResource = "Dodaj posiłek"
    static var description = IntentDescription("Otwiera Mealgram i pokazuje opcje dodania posiłku.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: AppShortcutAction.logMeal, object: nil)
        }
        return .result()
    }
}

/// Open the app and route to the Today tab.
struct ShowTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "Pokaż dzisiejszy posiłek"
    static var description = IntentDescription("Otwiera ekran Dziś w Mealgram.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: AppShortcutAction.showToday, object: nil)
        }
        return .result()
    }
}

/// Open the app and raise the weekly debrief sheet.
struct ShowWeeklyDebriefIntent: AppIntent {
    static var title: LocalizedStringResource = "Tygodniowe podsumowanie"
    static var description = IntentDescription("Otwiera podsumowanie tygodnia od Oli.")
    static var openAppWhenRun: Bool = true

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
struct MealgramShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogMealIntent(),
            phrases: [
                "Dodaj posiłek w \(.applicationName)",
                "Zapisz jedzenie w \(.applicationName)",
            ],
            shortTitle: "Dodaj posiłek",
            systemImageName: "plus.circle.fill"
        )
        AppShortcut(
            intent: ShowTodayIntent(),
            phrases: [
                "Pokaż dzisiaj w \(.applicationName)",
                "Co jadłem dzisiaj w \(.applicationName)",
            ],
            shortTitle: "Dziś",
            systemImageName: "sun.max.fill"
        )
        AppShortcut(
            intent: ShowWeeklyDebriefIntent(),
            phrases: [
                "Podsumowanie tygodnia w \(.applicationName)",
                "Co u mnie w \(.applicationName)",
            ],
            shortTitle: "Co u Ciebie",
            systemImageName: "sparkles"
        )
    }
}
