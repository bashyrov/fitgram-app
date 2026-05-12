import Foundation
import SwiftData

/// Glue between the SwiftData meal log + the notification planner.
/// `MealgramApp` calls `rescheduleAll(for:)` at launch and every meal
/// save (via `ChainedMealSaver`). Pure side-effect — no UI surface.
@MainActor
final class NotificationCoordinator {
    private let scheduler: any NotificationScheduling
    private let preferencesStore: NotificationPreferencesStore
    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling,
        preferencesStore: NotificationPreferencesStore = .init(),
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    /// Fires a one-off achievement-unlock alert so the user notices even
    /// when the app is backgrounded between the meal save and them
    /// returning. Idempotent at the scheduler level — repeats with the
    /// same title/body produce separate notifications (each unlock is
    /// genuinely distinct).
    func notifyAchievement(_ definition: AchievementDefinition) async {
        let title = String(localized: "Nowa odznaka: \(definition.title)")
        await scheduler.notifyAchievement(title: title, body: definition.summary)
    }

    func rescheduleAll(for userRemoteID: String) async {
        let plan = NotificationPlanner.plan(
            .init(
                preferences: preferencesStore.load(),
                hasLoggedToday: hasLoggedToday(for: userRemoteID),
                calendar: calendar,
                now: now()
            )
        )
        await scheduler.reschedule(plan: plan)
    }

    private func hasLoggedToday(for userRemoteID: String) -> Bool {
        let context = ModelContext(container)
        let dayStart = calendar.startOfDay(for: now())
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return false }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { entry in
                entry.consumedAt >= dayStart && entry.consumedAt < dayEnd
            }
        )
        let count = (try? context.fetchCount(descriptor)) ?? 0
        return count > 0
    }
}
