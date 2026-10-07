import SwiftUI

/// Notification preferences, theme, and unit toggles. Language lives only
/// in the dedicated Language settings screen.
struct PreferencesView: View {
    let user: User
    let onDismiss: () -> Void

    @AppStorage("preferences.theme") private var themeRaw = ThemePreference.auto.rawValue
    @AppStorage("preferences.morningReminderEnabled") private var morningEnabled = true
    @AppStorage("preferences.streakRiskEnabled") private var streakRiskEnabled = true
    @AppStorage("preferences.eveningReminderEnabled") private var eveningEnabled = true
    @AppStorage("preferences.goalWeightReminderEnabled") private var goalWeightEnabled = true
    @AppStorage("preferences.goalWeightReminderHour") private var goalWeightHour = 9
    @AppStorage("preferences.goalWeightReminderMinute") private var goalWeightMinute = 0

    private var goalReminderDate: Date {
        let comps = DateComponents(hour: goalWeightHour, minute: goalWeightMinute)
        return Calendar.current.date(from: comps) ?? Date()
    }

    private var goalWeightToggleLabel: String {
        let formatted = String(format: "%02d:%02d", goalWeightHour, goalWeightMinute)
        return String.localizedStringWithFormat(goalWeightReminderFormat, formatted)
    }
    @AppStorage("preferences.usesMetric") private var usesMetric = true
    @AppStorage("preferences.friend.requestReceivedEnabled") private var friendRequestEnabled = true
    @AppStorage("preferences.friend.requestAcceptedEnabled") private var friendAcceptedEnabled = true
    @AppStorage("preferences.friend.bigAchievementEnabled") private var friendAchievementEnabled = true
    @AppStorage("preferences.friend.reactionEnabled") private var friendReactionEnabled = true
    @AppStorage("preferences.friend.challengeEnabled") private var friendChallengeEnabled = true

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: preferencesTitle)
                    sectionHeader(number: "01", title: remindersTitle, top: 6)
                    VStack(spacing: 0) {
                        toggleRow(morningReminderTitle, isOn: $morningEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(streakRiskTitle, isOn: $streakRiskEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(eveningSummaryTitle, isOn: $eveningEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(goalWeightToggleLabel, isOn: $goalWeightEnabled)
                        if goalWeightEnabled {
                            MonoRowDivider()
                            MonoRow(icon: "clock", title: reminderTimeTitle) {
                                DatePicker(
                                    reminderTimeTitle,
                                    selection: Binding(
                                        get: { goalReminderDate },
                                        set: { newValue in
                                            let comps = Calendar.current.dateComponents(
                                                [.hour, .minute], from: newValue
                                            )
                                            goalWeightHour = comps.hour ?? 9
                                            goalWeightMinute = comps.minute ?? 0
                                        }
                                    ),
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .labelsHidden()
                                .tint(Tokens.Palette.ink)
                            }
                        }
                    }
                    .monoRowsCard()

                    sectionHeader(number: "02", title: friendsTitle, top: 12)
                    VStack(spacing: 0) {
                        toggleRow(newInvitationTitle, isOn: $friendRequestEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(acceptedInvitationTitle, isOn: $friendAcceptedEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(friendAchievementTitle, isOn: $friendAchievementEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(reactionTitle, isOn: $friendReactionEnabled)
                        MonoRowDivider(inset: 16)
                        toggleRow(friendChallengeTitle, isOn: $friendChallengeEnabled)
                    }
                    .monoRowsCard()
                    MonoHint(text: friendPushHint)
                        .padding(.top, 8)

                    sectionHeader(number: "03", title: appearanceTitle, top: 12)
                    VStack(alignment: .leading, spacing: 12) {
                        MonoLabel(text: themePickerTitle)
                        MonoSegmented(
                            selection: Binding(
                                get: { ThemePreference(rawValue: themeRaw) ?? .auto },
                                set: { themeRaw = $0.rawValue }
                            ),
                            options: ThemePreference.allCases.map { (value: $0, title: $0.label) }
                        )
                        MonoLabel(text: unitsTitle)
                        MonoSegmented(
                            selection: $usesMetric,
                            options: [(value: true, title: metricTitle), (value: false, title: imperialTitle)]
                        )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .monoCard(padding: 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(preferencesTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: closeTitle, action: onDismiss)
                }
            }
        }
    }

    /// `sec(n, title)` with the mockup's top margin (16 built in + `top`).
    private func sectionHeader(number: String, title: String, top: CGFloat) -> some View {
        MonoSectionHeader(number: number, title: title)
            .padding(.horizontal, 6)
            .padding(.top, top)
            .padding(.bottom, 12)
    }

    /// `toggle_row(title)` — title + Mono switch, no icon.
    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        MonoRow(title: title) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(MonoToggleStyle())
                .fixedSize()
        }
    }

    private var preferencesTitle: String {
        TL(pl: "Preferencje", en: "Preferences", uk: "Налаштування", ru: "Параметры", es: "Preferencias")
    }

    private var closeTitle: String {
        TL(pl: "Zamknij", en: "Close", uk: "Закрити", ru: "Закрыть", es: "Cerrar")
    }

    private var remindersTitle: String {
        TL(pl: "Przypomnienia", en: "Reminders", uk: "Нагадування", ru: "Напоминания", es: "Recordatorios")
    }

    private var morningReminderTitle: String {
        TL(
            pl: "Poranny budzik 8:00",
            en: "Morning reminder 8:00",
            uk: "Ранкове нагадування 8:00",
            ru: "Утреннее напоминание 8:00",
            es: "Recordatorio de mañana 8:00"
        )
    }

    private var streakRiskTitle: String {
        TL(
            pl: "Seria zagrożona 20:30",
            en: "Streak at risk 20:30",
            uk: "Серія під загрозою 20:30",
            ru: "Серия под угрозой 20:30",
            es: "Racha en riesgo 20:30"
        )
    }

    private var eveningSummaryTitle: String {
        TL(
            pl: "Wieczorne podsumowanie 21:00",
            en: "Evening summary 21:00",
            uk: "Вечірній підсумок 21:00",
            ru: "Вечерняя сводка 21:00",
            es: "Resumen de la noche 21:00"
        )
    }

    private var reminderTimeTitle: String {
        TL(
            pl: "Godzina przypomnienia",
            en: "Reminder time",
            uk: "Час нагадування",
            ru: "Время напоминания",
            es: "Hora del recordatorio"
        )
    }

    private var goalWeightReminderFormat: String {
        TL(
            pl: "Przypomnienie celu wagi (%@)",
            en: "Goal weight reminder (%@)",
            uk: "Нагадування про ціль ваги (%@)",
            ru: "Напоминание о цели веса (%@)",
            es: "Recordatorio del objetivo de peso (%@)"
        )
    }

    private var friendsTitle: String {
        TL(pl: "Znajomi", en: "Friends", uk: "Друзі", ru: "Друзья", es: "Amigos")
    }

    private var newInvitationTitle: String {
        TL(
            pl: "Nowe zaproszenie", en: "New invitation", uk: "Нове запрошення", ru: "Новое приглашение",
            es: "Nueva invitación")
    }

    private var acceptedInvitationTitle: String {
        TL(
            pl: "Zaakceptowane zaproszenie",
            en: "Accepted invitation",
            uk: "Прийняте запрошення",
            ru: "Принятое приглашение",
            es: "Invitación aceptada"
        )
    }

    private var friendAchievementTitle: String {
        TL(
            pl: "Duże osiągnięcie znajomego",
            en: "Friend's big achievement",
            uk: "Велике досягнення друга",
            ru: "Большое достижение друга",
            es: "Gran logro de un amigo"
        )
    }

    private var reactionTitle: String {
        TL(
            pl: "Reakcja na moje osiągnięcie",
            en: "Reaction to my achievement",
            uk: "Реакція на моє досягнення",
            ru: "Реакция на мое достижение",
            es: "Reacción a mi logro"
        )
    }

    private var friendChallengeTitle: String {
        TL(
            pl: "Wyzwanie od znajomego",
            en: "Challenge from a friend",
            uk: "Виклик від друга",
            ru: "Вызов от друга",
            es: "Reto de un amigo"
        )
    }

    private var friendPushHint: String {
        TL(
            pl: "Te opcje sterują powiadomieniami push od znajomych po włączeniu konta Supabase.",
            en: "These options control friend push notifications once the Supabase account is enabled.",
            uk: "Ці опції керують push-сповіщеннями від друзів після ввімкнення акаунта Supabase.",
            ru: "Эти параметры управляют push-уведомлениями от друзей после включения аккаунта Supabase.",
            es: "Estas opciones controlan las notificaciones push de amigos cuando se active la cuenta Supabase."
        )
    }

    private var appearanceTitle: String {
        TL(pl: "Wygląd", en: "Appearance", uk: "Вигляд", ru: "Внешний вид", es: "Apariencia")
    }

    private var themePickerTitle: String {
        TL(pl: "Motyw", en: "Theme", uk: "Тема", ru: "Тема", es: "Tema")
    }

    private var unitsTitle: String {
        TL(pl: "Jednostki", en: "Units", uk: "Одиниці", ru: "Единицы", es: "Unidades")
    }

    private var metricTitle: String {
        TL(pl: "Metryczne", en: "Metric", uk: "Метричні", ru: "Метрические", es: "Métricas")
    }

    private var imperialTitle: String {
        TL(pl: "Imperialne", en: "Imperial", uk: "Імперські", ru: "Имперские", es: "Imperiales")
    }
}
