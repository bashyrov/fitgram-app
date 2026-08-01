import Foundation
import OSLog
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
    private let freezePolicy: StreakFreezePolicy
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
        self.freezePolicy = StreakFreezePolicy(calendar: calendar)
        self.isGoalTrackingEligible = isGoalTrackingEligible
    }

    /// Fires a one-off achievement-unlock alert so the user notices even
    /// when the app is backgrounded between the meal save and them
    /// returning. Idempotent at the scheduler level — repeats with the
    /// same title/body produce separate notifications (each unlock is
    /// genuinely distinct).
    func notifyAchievement(_ definition: AchievementDefinition) async {
        let title = String.localizedStringWithFormat(L("Odblokowano: %@"), definition.title)
        let summary = definition.summary.trimmingCharacters(in: CharacterSet(charactersIn: ".!? "))
        let body = String.localizedStringWithFormat(
            L("%@. Zobacz odznakę i zachowaj ten rytm."),
            summary
        )
        await scheduler.notifyAchievement(title: title, body: body)
    }

    func notifyFriendReaction(from displayName: String, reaction: ReactionKind) async {
        let title = String.localizedStringWithFormat(L("%@ zareagował(a)"), displayName)
        let body = String.localizedStringWithFormat(
            L("%@ Twoje postępy dostały reakcję %@. Otwórz Znajomych i odpowiedz dobrym gestem."),
            displayName,
            reaction.emoji
        )
        await scheduler.notifyAchievement(title: title, body: body)
    }

    func notifyProteinNudge(remainingGrams: Int) async {
        let title = L("Białko jeszcze czeka")
        let body = String.localizedStringWithFormat(
            L("Brakuje około %lld g do celu. Skyr, twaróg albo kurczak szybko domkną dzień."),
            max(0, remainingGrams)
        )
        await scheduler.notifyAchievement(title: title, body: body)
    }

    func notifyEveningCaloriesLeft(remainingKcal: Int) async {
        let title = L("Masz jeszcze miejsce na spokojny wieczór")
        let body = String.localizedStringWithFormat(
            L("Zostało około %lld kcal. Dodaj kolację albo zostaw bufor, jeśli już czujesz sytość."),
            max(0, remainingKcal)
        )
        await scheduler.notifyAchievement(title: title, body: body)
    }

    func rescheduleAll(for userRemoteID: String) async {
        let currentDate = now()
        let streakSnapshot = streakSnapshot(for: userRemoteID, now: currentDate)
        let plan = NotificationPlanner.plan(
            .init(
                preferences: preferencesStore.load(),
                hasLoggedToday: hasLoggedToday(for: userRemoteID),
                calendar: calendar,
                now: currentDate,
                hasActiveGoal: isGoalTrackingEligible(userRemoteID),
                hasLoggedGoalWeightToday: hasLoggedGoalWeightToday(for: userRemoteID),
                currentStreakLength: streakSnapshot.currentLength,
                freezesAvailable: streakSnapshot.freezesAvailable,
                hasProtectedStreakToday: streakSnapshot.hasProtectedToday
            )
        )
        await scheduler.reschedule(plan: plan)
    }

    private func streakSnapshot(for userRemoteID: String, now: Date) -> StreakReminderSnapshot {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Streak>(
            predicate: #Predicate { $0.userRemoteID == userRemoteID }
        )
        guard let streak = try? context.fetch(descriptor).first else {
            return StreakReminderSnapshot.empty
        }
        _ = freezePolicy.reconcile(streak, now: now)
        _ = freezePolicy.awardEarnedFreezes(streak)
        do {
            try context.save()
        } catch {
            Logger.persistence.error("Failed to persist streak freeze reconciliation: \(String(describing: error))")
        }
        return StreakReminderSnapshot(
            currentLength: streak.currentLength,
            freezesAvailable: streak.freezesAvailable,
            hasProtectedToday: freezePolicy.hasProtectedToday(streak: streak, now: now)
        )
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

private struct StreakReminderSnapshot {
    var currentLength: Int
    var freezesAvailable: Int
    var hasProtectedToday: Bool

    static let empty = StreakReminderSnapshot(
        currentLength: 0,
        freezesAvailable: 0,
        hasProtectedToday: false
    )
}
