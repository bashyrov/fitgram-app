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

    /// Wipes any pending Fitgram notifications and re-schedules them
    /// from the given snapshot. Idempotent.
    func reschedule(plan: NotificationPlan) async

    /// Fires a one-off local notification immediately. Used for
    /// achievement unlocks so the user sees something even if the app
    /// is backgrounded between the meal save and them returning.
    func notifyAchievement(title: String, body: String) async

    /// Removes every pending/delivered Fitgram notification, including
    /// one-off achievement and social alerts with generated identifiers.
    func clearAllFitgramNotifications() async
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
    /// When true, the streak-risk copy points the user to freeze instead
    /// of asking for a fast meal log.
    var streakRiskSuggestsFreeze: Bool
    /// Generic evening wrap-up at 21:00, regardless of activity.
    var eveningSummary: DateComponents?
    /// Goal weight reminder — fires at the user-configured time (default
    /// 09:00) when the user has an active lose/gain goal, is Premium,
    /// and hasn't yet logged a weigh-in today.
    var goalWeight: DateComponents?
}

extension NotificationPlan {
    static let empty = NotificationPlan(
        morningGreeting: nil,
        streakRisk: nil,
        streakRiskSuggestsFreeze: false,
        eveningSummary: nil,
        goalWeight: nil
    )
}

/// Notification identifiers — kept stable so reschedules replace rather
/// than duplicate pending requests.
enum NotificationID {
    static let morning = "fitgram.morning"
    static let streakRisk = "fitgram.streak.risk"
    static let evening = "fitgram.evening"
    static let goalWeight = "fitgram.goal.weight"

    static var all: [String] {
        [morning, streakRisk, evening, goalWeight]
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
        await schedule(
            id: NotificationID.streakRisk,
            when: plan.streakRisk,
            content: Self.streakRiskContent(suggestsFreeze: plan.streakRiskSuggestsFreeze)
        )
        await schedule(id: NotificationID.evening, when: plan.eveningSummary, content: Self.eveningContent())
        await schedule(
            id: NotificationID.goalWeight,
            when: plan.goalWeight,
            content: Self.goalWeightContent()
        )
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
            identifier: "fitgram.achievement.\(UUID().uuidString)",
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

    func clearAllFitgramNotifications() async {
        center.removePendingNotificationRequests(withIdentifiers: NotificationID.all)
        center.removeDeliveredNotifications(withIdentifiers: NotificationID.all)
        let pending = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("fitgram.") }
        let delivered = await center.deliveredNotifications()
            .map(\.request.identifier)
            .filter { $0.hasPrefix("fitgram.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        center.removeDeliveredNotifications(withIdentifiers: delivered)
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
        content.title = TL(
            pl: "Ola ma plan na dziś",
            en: "Ola has today's plan",
            uk: "Оля має план на сьогодні",
            ru: "У Оли есть план на сегодня",
            es: "Ola tiene el plan de hoy"
        )
        content.body = TL(
            pl: "Zacznij od białka, a kalorie łatwiej utrzymają się w ryzach. Otwórz Fitgram po swój plan.",
            en: "Start with protein and calories are easier to steer. Open Fitgram for your plan.",
            uk: "Почни з білка, і калорії легше тримати в межах. Відкрий Fitgram для плану.",
            ru: "Начни с белка, и калории проще удержать в рамках. Открой Fitgram за планом.",
            es: "Empieza con proteína y será más fácil controlar calorías. Abre Fitgram para ver el plan."
        )
        content.sound = .default
        return content
    }

    private static func streakRiskContent(suggestsFreeze: Bool) -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        if suggestsFreeze {
            content.title = TL(
                pl: "Seria jest do uratowania",
                en: "Your streak can still be saved",
                uk: "Серію ще можна врятувати",
                ru: "Серию ещё можно спасти",
                es: "Tu racha aún se puede salvar"
            )
            content.body = TL(
                pl: "Nie ma dziś wpisu. Możesz użyć freeze jednym tapnięciem albo dodać szybki posiłek.",
                en: "No entry today. Use a freeze with one tap or add a quick meal.",
                uk: "Сьогодні ще немає запису. Використай фриз одним дотиком або додай швидку їжу.",
                ru: "Сегодня ещё нет записи. Используй фриз одним касанием или добавь быстрый приём пищи.",
                es: "Hoy no hay registro. Usa un freeze con un toque o añade una comida rápida."
            )
        } else {
            content.title = TL(
                pl: "Twoja seria czeka na jeden ruch",
                en: "Your streak needs one small move",
                uk: "Твоїй серії потрібен один крок",
                ru: "Твоей серии нужен один шаг",
                es: "Tu racha necesita un pequeño paso"
            )
            content.body = TL(
                pl: "Dodaj cokolwiek z dzisiejszego dnia, nawet prostą przekąskę. Liczy się rytm.",
                en: "Add anything from today, even a simple snack. The rhythm matters.",
                uk: "Додай щось за сьогодні, навіть простий перекус. Важливий ритм.",
                ru: "Добавь что-нибудь за сегодня, даже простой перекус. Важен ритм.",
                es: "Añade algo de hoy, incluso un snack sencillo. El ritmo cuenta."
            )
        }
        content.sound = .default
        return content
    }

    private static func eveningContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = TL(
            pl: "Ola sprawdziła wieczór",
            en: "Ola checked the evening",
            uk: "Оля перевірила вечір",
            ru: "Оля проверила вечер",
            es: "Ola revisó la noche"
        )
        content.body = TL(
            pl: "Jeśli zostały kalorie, wystarczy lekka kolacja. Jeśli dzień domknięty — nie wciskamy nic na siłę.",
            en: "If calories are left, a light dinner is enough. If the day is closed, no need to force food.",
            uk: "Якщо калорії лишились, вистачить легкої вечері. Якщо день закритий — не треба їсти силою.",
            ru: "Если калории остались, хватит лёгкого ужина. Если день закрыт — не нужно есть через силу.",
            es: "Si quedan calorías, basta una cena ligera. Si el día está cerrado, no hace falta forzar comida."
        )
        content.sound = .default
        return content
    }

    private static func goalWeightContent() -> UNNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = TL(
            pl: "Mały pomiar, lepszy plan",
            en: "Small weigh-in, better plan",
            uk: "Малий замір, кращий план",
            ru: "Маленькое взвешивание, лучший план",
            es: "Pequeña medición, mejor plan"
        )
        content.body = TL(
            pl: "Wpisz dzisiejszą wagę. Trend jest ważniejszy niż pojedyncza liczba.",
            en: "Log today's weight. The trend matters more than one number.",
            uk: "Запиши сьогоднішню вагу. Тренд важливіший за одне число.",
            ru: "Запиши сегодняшний вес. Тренд важнее одной цифры.",
            es: "Registra tu peso de hoy. La tendencia importa más que un número."
        )
        content.sound = .default
        return content
    }
}
