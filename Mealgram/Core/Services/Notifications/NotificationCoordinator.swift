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
    private let weightService: WeightService?
    /// Returns `true` when the user has an active lose / gain goal *and*
    /// is Premium. Injected as a closure so the coordinator doesn't have
    /// to drag the EntitlementsStore (a SwiftUI Observable) into its API.
    private let isGoalTrackingEligible: (String) -> Bool

    init(
        scheduler: any NotificationScheduling,
        preferencesStore: NotificationPreferencesStore = .init(),
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        weightService: WeightService? = nil,
        isGoalTrackingEligible: @escaping (String) -> Bool = { _ in false }
    ) {
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
        self.container = container
        self.calendar = calendar
        self.now = now
        self.weightService = weightService
        self.isGoalTrackingEligible = isGoalTrackingEligible
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
                now: now(),
                hasActiveGoal: isGoalTrackingEligible(userRemoteID),
                hasLoggedGoalWeightToday: hasLoggedGoalWeightToday(for: userRemoteID)
            )
        )
        await scheduler.reschedule(plan: plan)
    }

    private func hasLoggedGoalWeightToday(for userRemoteID: String) -> Bool {
        guard let weightService else { return false }
        return weightService.hasEntry(for: userRemoteID, on: now(), calendar: calendar)
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
