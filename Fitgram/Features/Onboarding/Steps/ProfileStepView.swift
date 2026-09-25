import SwiftUI

struct ProfileStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var heightCm: Double = 170
    @State private var weightKg: Double = 70
    @State private var ageYears: Int = 25

    var body: some View {
        OnboardingStepScaffold(
            title: "About you",
            subtitle: "These details help us tailor your calorie and macro targets.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            secondaryTitle: "Prefer to skip",
            secondaryAction: onContinue,
            onPrimary: {
                commit()
                onContinue()
            },
            content: {
                VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                    section("Sex") {
                        biologicalSexCards
                    }
                    section("Age") {
                        ageCard
                    }
                    section("Height") {
                        sliderCard(
                            config: SliderConfig(
                                symbol: "ruler",
                                unit: "cm",
                                range: 130...220,
                                step: 1,
                                integerDisplay: true,
                                tint: Tokens.Palette.primary
                            ),
                            binding: $heightCm
                        )
                    }
                    section("Weight") {
                        sliderCard(
                            config: SliderConfig(
                                symbol: "scalemass",
                                unit: "kg",
                                range: 30...200,
                                step: 0.5,
                                integerDisplay: false,
                                tint: Tokens.Palette.accent
                            ),
                            binding: $weightKg
                        )
                    }
                    section("Activity level") {
                        activityCards
                    }
                }
            }
        )
        .onAppear { hydrate() }
    }

    // MARK: - Sections

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
                symbol: "figure.stand.dress",
                title: "Female",
                subtitle: "",
                isSelected: profile.biologicalSex == .female,
                action: { profile.biologicalSex = .female }
            )
            OnboardingChoiceCard(
                symbol: "figure.stand",
                title: "Male",
                subtitle: "",
                isSelected: profile.biologicalSex == .male,
                action: { profile.biologicalSex = .male }
            )
            OnboardingChoiceCard(
                symbol: "person.fill.questionmark",
                title: "Prefer not to say",
                subtitle: "No impact on recommendations",
                isSelected: profile.biologicalSex == .undisclosed,
                action: { profile.biologicalSex = .undisclosed }
            )
        }
    }

    private var ageCard: some View {
        HStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 48, height: 48)
                Image(systemName: "calendar")
                    .foregroundStyle(Tokens.Palette.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(ageYears)")
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("lat")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            Stepper("", value: $ageYears, in: 13...100)
                .labelsHidden()
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
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

    // MARK: - Slider card

    private struct SliderConfig {
        let symbol: String
        let unit: String
        let range: ClosedRange<Double>
        let step: Double
        let integerDisplay: Bool
        let tint: Color
    }

    private func sliderCard(
        config: SliderConfig,
        binding: Binding<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(config.tint.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: config.symbol)
                        .foregroundStyle(config.tint)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(formattedValue(binding.wrappedValue, integer: config.integerDisplay))
                        .font(Tokens.Font.display)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(config.unit)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
            }
            Slider(value: binding, in: config.range, step: config.step) {
                EmptyView()
            } minimumValueLabel: {
                Text(formattedValue(config.range.lowerBound, integer: config.integerDisplay))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            } maximumValueLabel: {
                Text(formattedValue(config.range.upperBound, integer: config.integerDisplay))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .tint(config.tint)
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }

    private func formattedValue(_ value: Double, integer: Bool) -> String {
        if integer {
            return "\(Int(value))"
        }
        return String(format: "%.1f", value)
            .replacingOccurrences(of: ".", with: ",")
    }

    // MARK: - State

    private func hydrate() {
        if let height = profile.heightCm { heightCm = Double(height) }
        if let weight = profile.weightKg { weightKg = weight }
        if let birth = profile.birthDate {
            ageYears = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 25
        }
    }

    private func commit() {
        profile.heightCm = Int(heightCm)
        profile.weightKg = weightKg
        let calendar = Calendar.current
        let now = Date()
        if let birth = calendar.date(byAdding: .year, value: -ageYears, to: now) {
            profile.birthDate = birth
        }
    }
}

extension ActivityLevel {
    fileprivate var label: String {
        switch self {
        case .sedentary: return L("Sedentary")
        case .light: return L("Light activity")
        case .moderate: return L("Umiarkowana")
        case .active: return L("Aktywny tryb")
        case .veryActive: return L("Very active")
        }
    }

    fileprivate var subtitle: String {
        switch self {
        case .sedentary: return L("Office work, little movement")
        case .light: return L("1–2 lekkie treningi w tygodniu")
        case .moderate: return L("3–4 treningi w tygodniu")
        case .active: return L("5+ workouts a week")
        case .veryActive: return L("Trening dwa razy dziennie")
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
