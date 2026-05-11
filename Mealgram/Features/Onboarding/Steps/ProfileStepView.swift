import SwiftUI

struct ProfileStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var heightInput: String = ""
    @State private var weightInput: String = ""

    var body: some View {
        OnboardingStepScaffold(
            title: "Krótko o Tobie",
            subtitle: "Dzięki tym danym dopasujemy cele kaloryczne i makro.",
            primaryTitle: "Dalej",
            primarySystemImage: "arrow.right",
            primaryEnabled: !heightInput.isEmpty && !weightInput.isEmpty,
            secondaryTitle: "Wolę pominąć",
            secondaryAction: onContinue,
            onPrimary: {
                commit()
                onContinue()
            },
            content: {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    section("Płeć") {
                        biologicalSexCards
                    }
                    section("Poziom aktywności") {
                        activityCards
                    }
                    section("Twoje wymiary") {
                        measurementFields
                    }
                }
            }
        )
        .onAppear { hydrate() }
    }

    // MARK: - Helpers

    private func section<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            content()
        }
    }

    private var biologicalSexCards: some View {
        VStack(spacing: Tokens.Space.sm) {
            OnboardingChoiceCard(
                symbol: "figure.dress",
                title: "Kobieta",
                subtitle: "",
                isSelected: profile.biologicalSex == .female,
                action: { profile.biologicalSex = .female }
            )
            OnboardingChoiceCard(
                symbol: "figure",
                title: "Mężczyzna",
                subtitle: "",
                isSelected: profile.biologicalSex == .male,
                action: { profile.biologicalSex = .male }
            )
            OnboardingChoiceCard(
                symbol: "ellipsis.circle",
                title: "Nie podaję",
                subtitle: "Bez wpływu na rekomendacje",
                isSelected: profile.biologicalSex == .undisclosed,
                action: { profile.biologicalSex = .undisclosed }
            )
        }
    }

    private var activityCards: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(ActivityLevel.allCases, id: \.self) { level in
                OnboardingChoiceCard(
                    symbol: level.symbol,
                    title: LocalizedStringKey(level.label),
                    subtitle: LocalizedStringKey(level.subtitle),
                    isSelected: profile.activityLevel == level,
                    action: { profile.activityLevel = level }
                )
            }
        }
    }

    private var measurementFields: some View {
        VStack(spacing: Tokens.Space.md) {
            measurementField(
                label: "Wzrost (cm)",
                placeholder: "170",
                text: $heightInput,
                systemImage: "ruler"
            )
            measurementField(
                label: "Waga (kg)",
                placeholder: "70.5",
                text: $weightInput,
                systemImage: "scalemass"
            )
        }
    }

    private func measurementField(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        systemImage: String
    ) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: systemImage)
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                TextField(placeholder, text: text)
                    .keyboardType(.decimalPad)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
    }

    // MARK: - State

    private func hydrate() {
        if let height = profile.heightCm { heightInput = "\(height)" }
        if let weight = profile.weightKg { weightInput = "\(weight)" }
    }

    private func commit() {
        if let height = Int(heightInput) {
            profile.heightCm = height
        }
        if let weight = Double(weightInput.replacingOccurrences(of: ",", with: ".")) {
            profile.weightKg = weight
        }
    }
}

extension ActivityLevel {
    fileprivate var label: String {
        switch self {
        case .sedentary: return "Siedzący tryb"
        case .light: return "Lekka aktywność"
        case .moderate: return "Umiarkowana"
        case .active: return "Aktywny tryb"
        case .veryActive: return "Bardzo aktywny"
        }
    }

    fileprivate var subtitle: String {
        switch self {
        case .sedentary: return "Praca biurowa, mało ruchu"
        case .light: return "1–2 lekkie treningi w tygodniu"
        case .moderate: return "3–4 treningi w tygodniu"
        case .active: return "5+ treningów w tygodniu"
        case .veryActive: return "Trening dwa razy dziennie"
        }
    }

    fileprivate var symbol: String {
        switch self {
        case .sedentary: return "chair"
        case .light: return "figure.walk"
        case .moderate: return "figure.run"
        case .active: return "figure.strengthtraining.traditional"
        case .veryActive: return "flame.fill"
        }
    }
}
