import Foundation
import OSLog
import SwiftData

/// Glue between the SwiftData meal log + the notification planner.
/// `FitgramApp` calls `rescheduleAll(for:)` at launch and every meal
/// save (via `ChainedMealSaver`). Pure side-effect — no UI surface.
@MainActor
final class NotificationCoordinator {
    private let scheduler: any NotificationScheduling
    private let preferencesStore: NotificationPreferencesStore
    private let deliveryStore: NotificationDeliveryStore
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
        deliveryStore: NotificationDeliveryStore = .init(),
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        weightService: WeightService? = nil,
        isGoalTrackingEligible: @escaping (String) -> Bool = { _ in false }
    ) {
        self.scheduler = scheduler
        self.preferencesStore = preferencesStore
        self.deliveryStore = deliveryStore
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

    func notifyNewFriendReactions(_ reactions: [FriendReactionNotification]) async {
        guard UserDefaults.standard.boolWithDefaultTrue(forKey: "preferences.friend.reactionEnabled") else { return }
        for reaction in reactions where deliveryStore.markFriendReactionIfNeeded(reaction.id) {
            await notifyFriendReaction(from: reaction.fromDisplayName, reaction: reaction.kind)
        }
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

    func notifyCalorieOvershoot() async {
        let title = L("Nie panikujemy")
        let body = L("Dzień wyszedł ponad cel. Jutro nie tniemy agresywnie — po prostu wracamy do rytmu.")
        await scheduler.notifyAchievement(title: title, body: body)
    }

    func evaluateMealNudgesAfterSave(for userRemoteID: String) async {
        let snapshot = dailyNutritionSnapshot(for: userRemoteID)
        guard snapshot.hasLoggedToday else { return }

        let currentHour = calendar.component(.hour, from: now())
        let proteinRemaining = max(0, snapshot.proteinGoalGrams - snapshot.proteinConsumedGrams)
        if currentHour >= 15,
            snapshot.proteinGoalGrams > 0,
            proteinRemaining >= max(20, Int((Double(snapshot.proteinGoalGrams) * 0.25).rounded())),
            deliveryStore.markDailyIfNeeded(.proteinNudge, on: now(), calendar: calendar)
        {
            await notifyProteinNudge(remainingGrams: proteinRemaining)
        }

        let caloriesRemaining = max(0, snapshot.calorieGoalKcal - snapshot.caloriesConsumedKcal)
        if currentHour >= 18,
            snapshot.calorieGoalKcal > 0,
            caloriesRemaining >= 250,
            snapshot.caloriesConsumedKcal >= Int((Double(snapshot.calorieGoalKcal) * 0.45).rounded()),
            deliveryStore.markDailyIfNeeded(.eveningCaloriesLeft, on: now(), calendar: calendar)
        {
            await notifyEveningCaloriesLeft(remainingKcal: caloriesRemaining)
        }

        if snapshot.calorieGoalKcal > 0,
            snapshot.caloriesConsumedKcal >= Int((Double(snapshot.calorieGoalKcal) * 1.12).rounded()),
            deliveryStore.markDailyIfNeeded(.calorieOvershoot, on: now(), calendar: calendar)
        {
            await notifyCalorieOvershoot()
        }
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

    private func dailyNutritionSnapshot(for userRemoteID: String) -> DailyNutritionSnapshot {
        let context = ModelContext(container)
        let currentDate = now()
        let dayStart = calendar.startOfDay(for: currentDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return .empty
        }

        let userDescriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.remoteID == userRemoteID }
        )
        let user = try? context.fetch(userDescriptor).first
        let mealDescriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate { entry in
                entry.consumedAt >= dayStart && entry.consumedAt < dayEnd
            }
        )
        let meals = (try? context.fetch(mealDescriptor)) ?? []
        return DailyNutritionSnapshot(
            hasLoggedToday: !meals.isEmpty,
            caloriesConsumedKcal: Int(meals.reduce(0) { $0 + $1.totalCaloriesKcal }.rounded()),
            proteinConsumedGrams: Int(meals.reduce(0) { $0 + $1.totalProteinGrams }.rounded()),
            calorieGoalKcal: user?.dailyCalorieGoalKcal ?? 0,
            proteinGoalGrams: user?.proteinGoalGrams ?? 0
        )
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

private struct DailyNutritionSnapshot {
    let hasLoggedToday: Bool
    let caloriesConsumedKcal: Int
    let proteinConsumedGrams: Int
    let calorieGoalKcal: Int
    let proteinGoalGrams: Int

    static let empty = DailyNutritionSnapshot(
        hasLoggedToday: false,
        caloriesConsumedKcal: 0,
        proteinConsumedGrams: 0,
        calorieGoalKcal: 0,
        proteinGoalGrams: 0
    )
}

struct NotificationDeliveryStore {
    enum DailyKind: String, Sendable {
        case proteinNudge
        case eveningCaloriesLeft
        case calorieOvershoot
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func markDailyIfNeeded(_ kind: DailyKind, on date: Date, calendar: Calendar) -> Bool {
        let key = "notifications.delivered.\(kind.rawValue)"
        let stamp = Self.dayStamp(for: date, calendar: calendar)
        guard defaults.string(forKey: key) != stamp else { return false }
        defaults.set(stamp, forKey: key)
        return true
    }

    func markFriendReactionIfNeeded(_ id: UUID) -> Bool {
        let key = "notifications.friendReaction.\(id.uuidString)"
        guard defaults.object(forKey: key) == nil else { return false }
        defaults.set(Date().timeIntervalSince1970, forKey: key)
        pruneFriendReactionKeys(keeping: 160)
        return true
    }

    private func pruneFriendReactionKeys(keeping limit: Int) {
        let prefix = "notifications.friendReaction."
        let pairs = defaults.dictionaryRepresentation().compactMap { key, value -> (String, Double)? in
            guard key.hasPrefix(prefix), let timestamp = value as? Double else { return nil }
            return (key, timestamp)
        }
        guard pairs.count > limit else { return }
        let stale = pairs.sorted { $0.1 > $1.1 }.dropFirst(limit)
        for pair in stale {
            defaults.removeObject(forKey: pair.0)
        }
    }

    private static func dayStamp(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

extension UserDefaults {
    fileprivate func boolWithDefaultTrue(forKey key: String) -> Bool {
        object(forKey: key) == nil ? true : bool(forKey: key)
    }
}
