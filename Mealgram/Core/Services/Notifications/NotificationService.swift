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
    static let morning = "mealgram.morning"
    static let streakRisk = "mealgram.streak.risk"
    static let evening = "mealgram.evening"
    static let goalWeight = "mealgram.goal.weight"

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
        content.title = TL(
            pl: "Dzień dobry, zaczynamy lekko",
            en: "Good morning, start light",
            uk: "Доброго ранку, почнімо легко",
            ru: "Доброе утро, начнём спокойно",
            es: "Buenos días, empecemos suave"
        )
        content.body = TL(
            pl: "Dodaj pierwszy posiłek, a Ola od razu pokaże, jak domknąć dzień bez chaosu.",
            en: "Add your first meal and Ola will show how to land the day without chaos.",
            uk: "Додай перший прийом їжі, і Оля підкаже, як спокійно закрити день.",
            ru: "Добавь первый приём пищи, и Оля покажет, как спокойно закрыть день.",
            es: "Añade tu primera comida y Ola te dirá cómo cerrar el día sin caos."
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
            pl: "Wieczorne domknięcie",
            en: "Evening check-in",
            uk: "Вечірнє підбиття підсумків",
            ru: "Вечернее завершение",
            es: "Cierre de la noche"
        )
        content.body = TL(
            pl: "Sprawdź kalorie, wodę i białko. Jeśli coś zostało, aplikacja pokaże najprostszy następny krok.",
            en: "Check calories, water and protein. If anything is left, the app will show the simplest next step.",
            uk: "Перевір калорії, воду та білок. Якщо щось лишилось, додаток покаже найпростіший крок.",
            ru: "Проверь калории, воду и белок. Если что-то осталось, приложение покажет самый простой шаг.",
            es: "Revisa calorías, agua y proteína. Si falta algo, la app mostrará el siguiente paso más simple."
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
