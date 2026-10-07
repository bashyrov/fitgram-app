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
        .init(
            value: 0.25, label: L("Relaxed"), subtitle: L("0.25 kg / week"), symbol: "clock",
            severity: .gentle),
        .init(
            value: 0.5, label: L("Moderate"), subtitle: L("0.5 kg / week"), symbol: "chart.bar", severity: .gentle),
        .init(value: 0.75, label: L("Fast"), subtitle: L("0.75 kg / week"), symbol: "bolt", severity: .warn),
        .init(
            value: 1.0, label: L("Very fast"), subtitle: L("1 kg / week"), symbol: "flame",
            severity: .danger),
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
            title: profile.goal == .lose ? "Jak szybko?" : "How do you want to gain?",
            subtitle: "A gentler pace usually means longer-lasting results. You can change it later.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            onPrimary: {
                profile.goalPaceKgPerWeek = pace.value
                profile.goalTargetWeightKg = targetWeightKg
                onContinue()
            },
            content: {
                VStack(spacing: 10) {
                    targetSection
                    paceSection
                    if let estimatedDate {
                        VStack(alignment: .leading, spacing: 6) {
                            MonoLabel(text: L("Reach your goal"))
                            Text(estimatedDate.formatted(date: .long, time: .omitted))
                                .font(Tokens.Font.manrope(15, weight: 800))
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                        .monoCard(padding: 16)
                    }
                    if pace.severity == .danger {
                        warningCard
                    }
                }
            }
        )
    }

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Docelowa waga"))
                Spacer(minLength: 8)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.1f", targetWeightKg))
                        .font(Tokens.Font.monoNumber(30))
                        .foregroundStyle(Tokens.Palette.ink)
                        .contentTransition(.numericText())
                    Text(L("kg"))
                        .font(Tokens.Font.manrope(13, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
            VStack(spacing: 6) {
                Slider(value: $targetWeightKg, in: targetRange, step: 0.5)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(String(format: "%.0f", targetRange.lowerBound))
                    Spacer()
                    Text(String(format: "%.0f", targetRange.upperBound))
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            Text(String.localizedStringWithFormat(L("current %.1f kg"), currentWeightKg))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
    }

    private var targetRange: ClosedRange<Double> {
        max(40, currentWeightKg - 25)...min(180, currentWeightKg + 25)
    }

    private var paceSection: some View {
        VStack(spacing: 8) {
            ForEach(Array(paceOptions.enumerated()), id: \.element.value) { index, option in
                OnboardingChoiceCard(
                    symbol: option.symbol,
                    title: LocalizedStringKey(option.label),
                    subtitle: LocalizedStringKey(option.subtitle),
                    isSelected: paceIndex == index,
                    action: { paceIndex = index }
                )
            }
        }
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Mono.fat)
            Text("That's an intense pace. Sustainable results come at 0.25-0.5 kg/week. Consult a dietician.")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
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
