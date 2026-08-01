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
            ZStack {
                preferencesBackground
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text(remindersTitle)
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Toggle(morningReminderTitle, isOn: $morningEnabled)
                                Toggle(streakRiskTitle, isOn: $streakRiskEnabled)
                                Toggle(eveningSummaryTitle, isOn: $eveningEnabled)
                                Toggle(goalWeightToggleLabel, isOn: $goalWeightEnabled)
                                if goalWeightEnabled {
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
                                }
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text(friendsTitle)
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Toggle(newInvitationTitle, isOn: $friendRequestEnabled)
                                Toggle(acceptedInvitationTitle, isOn: $friendAcceptedEnabled)
                                Toggle(friendAchievementTitle, isOn: $friendAchievementEnabled)
                                Toggle(reactionTitle, isOn: $friendReactionEnabled)
                                Toggle(friendChallengeTitle, isOn: $friendChallengeEnabled)
                                Text(friendPushHint)
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text(appearanceTitle)
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Picker(
                                    themePickerTitle,
                                    selection: Binding(
                                        get: { ThemePreference(rawValue: themeRaw) ?? .auto },
                                        set: { themeRaw = $0.rawValue }
                                    )
                                ) {
                                    ForEach(ThemePreference.allCases) { option in
                                        Text(option.label).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text(unitsTitle)
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Picker(unitsTitle, selection: $usesMetric) {
                                    Text(metricTitle).tag(true)
                                    Text(imperialTitle).tag(false)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(preferencesTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(closeTitle, action: onDismiss)
                }
            }
        }
    }

    private var preferencesBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.42))
                .frame(width: 350, height: 350)
                .blur(radius: 108)
                .offset(x: -160, y: -220)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.22))
                .frame(width: 310, height: 310)
                .blur(radius: 112)
                .offset(x: 160, y: -20)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.08))
                .frame(width: 250, height: 250)
                .blur(radius: 100)
                .offset(x: -80, y: 390)
        }
        .ignoresSafeArea()
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
