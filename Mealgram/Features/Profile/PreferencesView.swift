import SwiftData
import SwiftUI

/// Notification preferences, language, and unit toggles. Persisted to the
/// User row (`locale` for language); reminder windows are stored in
/// UserDefaults until M1.10 ships a richer notification scheduler.
struct PreferencesView: View {
    let user: User
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
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
        return String(localized: "Przypomnienie o wadze celu (\(formatted))")
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
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Język")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Picker(
                                    "Język",
                                    selection: Binding(
                                        get: { LanguageOption.from(locale: user.locale) },
                                        set: { newValue in
                                            user.locale = newValue.localeIdentifier
                                            user.updatedAt = Date()
                                            try? modelContext.save()
                                        }
                                    )
                                ) {
                                    ForEach(LanguageOption.allCases, id: \.self) { option in
                                        Text(option.label).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Przypomnienia")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Toggle("Poranny budzik 8:00", isOn: $morningEnabled)
                                Toggle("Seria zagrożona 20:30", isOn: $streakRiskEnabled)
                                Toggle("Wieczorne podsumowanie 21:00", isOn: $eveningEnabled)
                                Toggle(goalWeightToggleLabel, isOn: $goalWeightEnabled)
                                if goalWeightEnabled {
                                    DatePicker(
                                        "Godzina przypomnienia",
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
                                Text("Znajomi")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Toggle("Nowe zaproszenie", isOn: $friendRequestEnabled)
                                Toggle("Zaakceptowane zaproszenie", isOn: $friendAcceptedEnabled)
                                Toggle("Duże osiągnięcie znajomego", isOn: $friendAchievementEnabled)
                                Toggle("Reakcja na moje osiągnięcie", isOn: $friendReactionEnabled)
                                Toggle("Wyzwanie od znajomego", isOn: $friendChallengeEnabled)
                                Text("Sterują wysyłką push z naszego serwera — działają od momentu wprowadzenia konta Supabase.")
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                        }

                        Card {
                            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                                Text("Wygląd")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Picker(
                                    "Motyw",
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
                                Text("Jednostki")
                                    .font(Tokens.Font.headline)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Picker("Jednostki", selection: $usesMetric) {
                                    Text("Metryczne").tag(true)
                                    Text("Imperialne").tag(false)
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Preferencje"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }
}

enum LanguageOption: String, CaseIterable, Hashable {
    case polish
    case english
    case ukrainian

    var localeIdentifier: String {
        switch self {
        case .polish: return "pl_PL"
        case .english: return "en_US"
        case .ukrainian: return "uk_UA"
        }
    }

    var label: String {
        switch self {
        case .polish: return "Polski"
        case .english: return "English"
        case .ukrainian: return "Українська"
        }
    }

    static func from(locale: String) -> LanguageOption {
        if locale.hasPrefix("pl") { return .polish }
        if locale.hasPrefix("uk") { return .ukrainian }
        return .english
    }
}
