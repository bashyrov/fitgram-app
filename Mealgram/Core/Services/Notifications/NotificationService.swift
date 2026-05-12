import Foundation
import OSLog
import UserNotifications

/// What every concrete notification backend has to deliver. Protocol-
/// fronted so tests can exercise the scheduling rules against a fake
/// centre without touching `UNUserNotificationCenter`.
@MainActor
protocol NotificationScheduling: Sendable {
    /// Requests provisional alert permission. Returns the granted flag.
    func requestAuthorization() async -> Bool

    /// Current authorisation status — used by the Profile screen to show
    /// "Włączone / Wyłączone" copy.
    func currentStatus() async -> UNAuthorizationStatus

    /// Wipes any pending Mealgram notifications and re-schedules them
    /// from the given snapshot. Idempotent.
    func reschedule(plan: NotificationPlan) async

    /// Fires a one-off local notification immediately. Used for
    /// achievement unlocks so the user sees something even if the app
    /// is backgrounded between the meal save and them returning.
    func notifyAchievement(title: String, body: String) async
}

/// What to schedule. Computed by `NotificationPlanner.plan(...)`; the
/// service trusts the plan and just commits it to the system centre.
struct NotificationPlan: Equatable, Sendable {
    /// Local time of the morning nudge, e.g. 08:00. Skipped if the user
    /// has already logged a meal today.
    var morningGreeting: DateComponents?
    /// Streak-at-risk reminder — fires when the user's streak hasn't
    /// been refreshed today and the clock is getting close to midnight.
    var streakRisk: DateComponents?
    /// Generic evening wrap-up at 21:00, regardless of activity.
    var eveningSummary: DateComponents?
}

extension NotificationPlan {
    static let empty = NotificationPlan(
        morningGreeting: nil,
        streakRisk: nil,
        eveningSummary: nil
    )
}

/// Notification identifiers — kept stable so reschedules replace rather
/// than duplicate pending requests.
enum NotificationID {
    static let morning = "mealgram.morning"
    static let streakRisk = "mealgram.streak.risk"
    static let evening = "mealgram.evening"

    static var all: [String] {
        [morning, streakRisk, evening]
    }
}

/// Production implementation. Talks to `UNUserNotificationCenter`.
@MainActor
final class NotificationService: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.persistence.error("Notification auth request failed: \(String(describing: error))")
            return false
        }
    }

    func currentStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func reschedule(plan: NotificationPlan) async {
        center.removePendingNotificationRequests(withIdentifiers: NotificationID.all)
        let status = await currentStatus()
        guard status == .authorized || status == .provisional else {
            return
        }
        await schedule(id: NotificationID.morning, when: plan.morningGreeting, content: Self.morningContent())
        await schedule(id: NotificationID.streakRisk, when: plan.streakRisk, content: Self.streakRiskContent())
        await schedule(id: NotificationID.evening, when: plan.eveningSummary, content: Self.eveningContent())
    }

    func notifyAchievement(title: String, body: String) async {
        let status = await currentStatus()
        guard status == .authorized || status == .provisional else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // 1-second trigger so the system still routes the alert when the
        // app is backgrounded; if the user is in-foreground the
        // AchievementUnlockBanner is the visible feedback anyway.
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "mealgram.achievement.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            Logger.persistence.error(
                "Failed to schedule achievement notification: \(String(describing: error))"
            )
        }
    }

    private func schedule(id: String, when components: DateComponents?, content: UNNotificationContent) async {
        guard let components else { return }
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            Logger.persistence.error("Failed to schedule \(id): \(String(describing: error))")
        }
    }

    private static func morningContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Dzień dobry!")
        content.body = String(localized: "Gotów na śniadanie? Stuknij, żeby dodać posiłek.")
        content.sound = .default
        return content
    }

    private static func streakRiskContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Twoja seria czeka")
        content.body = String(localized: "Jeszcze nic dziś nie dodałaś — szybki wpis utrzyma serię.")
        content.sound = .default
        return content
    }

    private static func eveningContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Podsumowanie dnia")
        content.body = String(localized: "Zerknij, jak minął dzień i co jeszcze warto dodać.")
        content.sound = .default
        return content
    }
}
