import SwiftData
import SwiftUI

/// Notification preferences, language, and unit toggles. Persisted to the
/// User row (`locale` for language); reminder windows are stored in
/// UserDefaults until M1.10 ships a richer notification scheduler.
struct PreferencesView: View {
    let user: User
    let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext
    @AppStorage("preferences.morningReminderEnabled") private var morningEnabled = true
    @AppStorage("preferences.streakRiskEnabled") private var streakRiskEnabled = true
    @AppStorage("preferences.eveningReminderEnabled") private var eveningEnabled = true
    @AppStorage("preferences.usesMetric") private var usesMetric = true

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
