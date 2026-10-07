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
                VStack(alignment: .leading, spacing: 10) {
                    sexCard
                    measurementsCard
                    activityCard
                }
            }
        )
        .onAppear { hydrate() }
    }

    // MARK: - Cards

    private var sexCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Sex"))
            MonoSegmented(
                selection: $profile.biologicalSex,
                options: [
                    (value: BiologicalSex.female, title: L("Female")),
                    (value: BiologicalSex.male, title: L("Male")),
                    (value: BiologicalSex.undisclosed, title: L("Prefer not to say")),
                ]
            )
            Text(L("No impact on recommendations"))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
    }

    private var measurementsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepperRow(
                title: L("Age"),
                value: Binding(
                    get: { Double(ageYears) },
                    set: { ageYears = Int($0.rounded()) }
                ),
                range: 13...100,
                step: 1,
                unit: L("lat"),
                format: "%.0f"
            )
            stepperRow(title: L("Height"), value: $heightCm, range: 130...220, step: 1, unit: "cm", format: "%.0f")
            stepperRow(title: L("Weight"), value: $weightKg, range: 30...200, step: 0.5, unit: "kg", format: "%.1f")
        }
        .monoCard(padding: 16)
    }

    // swiftlint:disable:next function_parameter_count
    private func stepperRow(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        unit: String,
        format: String
    ) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            MonoStepper(value: value, range: range, step: step, unit: unit, format: format)
        }
    }

    private var activityLevels: [ActivityLevel] { ActivityLevel.allCases }

    /// Discrete slider over `ActivityLevel.allCases` (index-backed).
    private var activityIndex: Binding<Double> {
        Binding(
            get: { Double(activityLevels.firstIndex(of: profile.activityLevel) ?? 0) },
            set: { newValue in
                let index = min(max(Int(newValue.rounded()), 0), activityLevels.count - 1)
                if activityLevels[index] != profile.activityLevel {
                    profile.activityLevel = activityLevels[index]
                    Haptics.selection()
                }
            }
        )
    }

    private var activityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Activity level"))
            VStack(spacing: 6) {
                Slider(value: activityIndex, in: 0...Double(max(activityLevels.count - 1, 1)), step: 1)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(activityLevels.first?.label ?? "")
                    Spacer()
                    Text(activityLevels.last?.label ?? "")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            Text("\(profile.activityLevel.label) · \(profile.activityLevel.subtitle)")
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
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
