import SwiftUI

/// Last "review your plan" screen before the user lands in the app.
/// Design D "Twój plan": hero calorie target with macro pills, photo-scan
/// reference picker, Ola's per-user advice.
struct CalibrationStepView: View {
    @Binding var profile: OnboardingProfile
    var computedTargets: GoalCalculator.Targets?
    var recommendations: Recommendations?
    var isLoadingRecommendations: Bool
    let onContinue: () -> Void

    @State private var reference: ReferenceObjectKind = .creditCard

    var body: some View {
        OnboardingStepScaffold(
            title: "Your plan",
            subtitle: "You can change all of this later in Profile.",
            primaryTitle: "Continue",
            primarySystemImage: "checkmark",
            onPrimary: onContinue,
            content: {
                VStack(alignment: .leading, spacing: 0) {
                    if let computedTargets {
                        DailyTargetHeroCard(targets: computedTargets)
                    }
                    referenceSection
                    recommendationsCard
                        .padding(.top, 10)
                }
            }
        )
    }

    @ViewBuilder
    private var recommendationsCard: some View {
        if let recommendations {
            OlaPlanCard(recommendations: recommendations)
        } else if isLoadingRecommendations {
            OlaPlanLoadingCard()
        }
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Reference for photo scans"))
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 12)
            VStack(spacing: 8) {
                OnboardingChoiceCard(
                    symbol: "creditcard",
                    title: "Credit card",
                    subtitle: "Most commonly used reference",
                    isSelected: reference == .creditCard,
                    action: { reference = .creditCard }
                )
                OnboardingChoiceCard(
                    symbol: "hand.raised",
                    title: "Your hand",
                    subtitle: "Always with you",
                    isSelected: reference == .eatingHand,
                    action: { reference = .eatingHand }
                )
                OnboardingChoiceCard(
                    symbol: "fork.knife",
                    title: "Cutlery",
                    subtitle: "Spoon, fork — compared with the plate",
                    isSelected: reference == .fork,
                    action: { reference = .fork }
                )
            }
        }
    }
}

// MARK: - Hero calorie card

/// Dark hero: daily kcal, macro pills and water / fiber / safety line.
private struct DailyTargetHeroCard: View {
    let targets: GoalCalculator.Targets

    private var footnote: String {
        var parts = [
            "\(L("Woda")) \(targets.waterGoalMl) \(L("ml"))",
            "\(L("Fiber")) \(targets.fiberGoalGrams) \(L("g"))",
        ]
        if targets.hitSafetyFloor {
            parts.append(L("Tempo dostosowane do bezpiecznego minimum"))
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoLabel(text: L("Your daily target"), onHero: true)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: "\(targets.dailyCalorieGoalKcal)")
                    .font(Tokens.Font.monoNumber(64))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(verbatim: "kcal")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            MonoMacroRow(
                protein: Double(targets.proteinGoalGrams),
                carbs: Double(targets.carbsGoalGrams),
                fat: Double(targets.fatGoalGrams),
                dark: true
            )
            Text(footnote)
                .font(Tokens.Font.manrope(13, weight: 700))
                .foregroundStyle(targets.hitSafetyFloor ? Tokens.Mono.hi : Tokens.Mono.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }
}

// MARK: - Ola's plan card

private struct OlaPlanCard: View {
    let recommendations: Recommendations

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            OlaHeader()

            Text(L(recommendations.summary))
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !recommendations.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    ForEach(recommendations.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Tokens.Mono.fat)
                                .frame(width: 16)
                            Text(L(warning))
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Mono.track)
                )
            }

            VStack(spacing: Tokens.Space.sm) {
                ForEach(recommendations.tips) { tip in
                    OlaTipRow(tip: tip)
                }
            }

            if !recommendations.nextSteps.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Tokens.Mono.strong)
                        .frame(width: 16)
                    Text(L(recommendations.nextSteps))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .monoCard(padding: 16)
    }
}

private struct OlaHeader: View {
    var body: some View {
        HStack(spacing: 10) {
            MonoIconBox(systemName: "sparkles", style: .dark, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                Text("Your plan from Ola")
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Personalised tips")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            Spacer()
        }
    }
}

private struct OlaTipRow: View {
    let tip: RecommendationTip

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Text(tip.icon)
                .font(.system(size: 22))
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                        .fill(Tokens.Mono.track)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(L(tip.title))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L(tip.description))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}

private struct OlaPlanLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            OlaHeader()
            LoadingShimmer().frame(height: 14)
            LoadingShimmer().frame(height: 14)
            LoadingShimmer().frame(height: 14).frame(maxWidth: 200, alignment: .leading)
            HStack(spacing: Tokens.Space.sm) {
                LoadingShimmer(cornerRadius: 18).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    LoadingShimmer().frame(height: 12)
                    LoadingShimmer().frame(height: 10).frame(maxWidth: 180, alignment: .leading)
                }
            }
            HStack(spacing: Tokens.Space.sm) {
                LoadingShimmer(cornerRadius: 18).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    LoadingShimmer().frame(height: 12)
                    LoadingShimmer().frame(height: 10).frame(maxWidth: 160, alignment: .leading)
                }
            }
        }
        .monoCard(padding: 16)
    }
}
