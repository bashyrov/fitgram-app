import SwiftUI

/// Pace + target-weight picker. Shown only when the user picked a
/// directional goal (`.lose` / `.gain`). For other goals OnboardingFlow
/// auto-skips this step.
///
/// Pace presets follow the spec — 0.25 / 0.5 / 0.75 / 1.0 kg per week —
/// with the bottom two marked as aggressive. Target-weight slider
/// covers ±25 kg of the user's current weight.
struct PaceStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var paceIndex: Int = 1  // default 0.5 kg/wk
    @State private var targetWeightKg: Double

    private let paceOptions: [PaceOption] = [
        .init(value: 0.25, label: "Spokojne", subtitle: "0,25 kg / tydzień", symbol: "tortoise.fill", severity: .gentle),
        .init(value: 0.5, label: "Umiarkowane", subtitle: "0,5 kg / tydzień", symbol: "figure.walk", severity: .gentle),
        .init(value: 0.75, label: "Szybkie", subtitle: "0,75 kg / tydzień", symbol: "figure.run", severity: .warn),
        .init(value: 1.0, label: "Bardzo szybkie", subtitle: "1 kg / tydzień", symbol: "exclamationmark.triangle", severity: .danger),
    ]

    init(profile: Binding<OnboardingProfile>, onContinue: @escaping () -> Void) {
        self._profile = profile
        self.onContinue = onContinue
        let current = profile.wrappedValue.weightKg ?? 70
        // For .lose default target = current − 5, .gain = current + 5
        let initialTarget = profile.wrappedValue.goal == .lose ? current - 5 : current + 5
        self._targetWeightKg = State(initialValue: max(40, min(180, initialTarget)))
    }

    private var currentWeightKg: Double { profile.weightKg ?? 70 }

    private var pace: PaceOption { paceOptions[paceIndex] }

    private var estimatedDate: Date? {
        GoalProjection.estimatedEndDate(
            currentWeightKg: currentWeightKg,
            targetWeightKg: targetWeightKg,
            paceKgPerWeek: pace.value
        )
    }

    var body: some View {
        OnboardingStepScaffold(
            title: profile.goal == .lose ? "Jak szybko?" : "Jak chcesz nabierać?",
            subtitle: "Wolniejsze tempo to zwykle trwalszy efekt. Możesz to zmienić później.",
            primaryTitle: "Dalej",
            primarySystemImage: "arrow.right",
            onPrimary: {
                profile.goalPaceKgPerWeek = pace.value
                profile.goalTargetWeightKg = targetWeightKg
                onContinue()
            },
            content: {
                VStack(spacing: Tokens.Space.lg) {
                    targetSection
                    paceSection
                    if let estimatedDate {
                        Card(background: Tokens.Palette.primarySoft) {
                            VStack(spacing: 4) {
                                Text("Osiągniesz cel")
                                    .font(Tokens.Font.footnote)
                                    .foregroundStyle(Tokens.Palette.primary)
                                Text(estimatedDate.formatted(date: .long, time: .omitted))
                                    .font(Tokens.Font.title3)
                                    .foregroundStyle(Tokens.Palette.ink)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    if pace.severity == .danger {
                        warningCard
                    }
                }
            }
        )
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Docelowa waga")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            HStack(alignment: .firstTextBaseline) {
                Text(String(format: "%.1f kg", targetWeightKg))
                    .font(Tokens.Font.title2)
                Spacer()
                Text(String(format: "obecna %.1f kg", currentWeightKg))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Slider(
                value: $targetWeightKg,
                in: max(40, currentWeightKg - 25)...min(180, currentWeightKg + 25),
                step: 0.5
            )
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
    }

    private var paceSection: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(Array(paceOptions.enumerated()), id: \.element.value) { index, option in
                Button {
                    paceIndex = index
                } label: {
                    HStack(spacing: Tokens.Space.md) {
                        Image(systemName: option.symbol)
                            .font(.system(size: 24))
                            .foregroundStyle(option.severity.tint)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                                .font(Tokens.Font.body)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(option.subtitle)
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer()
                        if paceIndex == index {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Tokens.Palette.primary)
                        }
                    }
                    .padding(Tokens.Space.md)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .fill(Tokens.Palette.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                                    .strokeBorder(
                                        paceIndex == index ? Tokens.Palette.primary : .clear,
                                        lineWidth: 2
                                    )
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Tokens.Palette.warning)
            Text("To bardzo intensywne tempo. Trwałe rezultaty przy 0,25-0,5 kg/tydzień. Skonsultuj z dietetykiem.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.warning.opacity(0.15))
        )
    }
}

private struct PaceOption: Identifiable {
    var id: Double { value }
    let value: Double
    let label: String
    let subtitle: String
    let symbol: String
    let severity: Severity

    enum Severity {
        case gentle, warn, danger

        var tint: Color {
            switch self {
            case .gentle: return Tokens.Palette.primary
            case .warn: return Tokens.Palette.warning
            case .danger: return Tokens.Palette.error
            }
        }
    }
}
