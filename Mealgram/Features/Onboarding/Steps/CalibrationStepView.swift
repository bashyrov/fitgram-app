import SwiftUI

/// Last "review your plan" screen before the user lands in the app.
/// Combines: hero calorie target, macro split tiles, secondary metrics,
/// Ola's per-user advice, photo-scan reference picker.
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
                VStack(spacing: Tokens.Space.lg) {
                    if let computedTargets {
                        DailyTargetHeroCard(targets: computedTargets)
                        MacroSplitRow(targets: computedTargets)
                        SecondaryMetricsRow(targets: computedTargets)
                    }
                    recommendationsCard
                    referenceSection
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
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Reference for photo scans")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            OnboardingChoiceCard(
                symbol: "creditcard.fill",
                title: "Credit card",
                subtitle: "Most commonly used reference",
                isSelected: reference == .creditCard,
                action: { reference = .creditCard }
            )
            OnboardingChoiceCard(
                symbol: "hand.raised.fill",
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

// MARK: - Hero calorie card

private struct DailyTargetHeroCard: View {
    let targets: GoalCalculator.Targets

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.primary.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(spacing: Tokens.Space.xs) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Your daily target")
                        .font(Tokens.Font.footnote.weight(.medium))
                }
                .foregroundStyle(.white.opacity(0.85))

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(targets.dailyCalorieGoalKcal)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                    Text("kcal")
                        .font(Tokens.Font.body.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .foregroundStyle(.white)

                if targets.hitSafetyFloor {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text("Tempo dostosowane do bezpiecznego minimum")
                    }
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, Tokens.Space.lg)
            .padding(.horizontal, Tokens.Space.lg)
        }
        .mealgramShadow(Tokens.Shadow.float)
    }
}

// MARK: - Macro split row (3 colored tiles)

private struct MacroSplitRow: View {
    let targets: GoalCalculator.Targets

    private var totalMacroKcal: Double {
        let proteinKcal = Double(targets.proteinGoalGrams) * 4
        let carbsKcal = Double(targets.carbsGoalGrams) * 4
        let fatKcal = Double(targets.fatGoalGrams) * 9
        return max(proteinKcal + carbsKcal + fatKcal, 1)
    }

    private var proteinPct: Int {
        Int((Double(targets.proteinGoalGrams) * 4 / totalMacroKcal * 100).rounded())
    }
    private var carbsPct: Int {
        Int((Double(targets.carbsGoalGrams) * 4 / totalMacroKcal * 100).rounded())
    }
    private var fatPct: Int {
        Int((Double(targets.fatGoalGrams) * 9 / totalMacroKcal * 100).rounded())
    }

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            MacroTile(
                color: Tokens.Palette.accent,
                label: "Protein",
                grams: targets.proteinGoalGrams,
                percent: proteinPct
            )
            MacroTile(
                color: Tokens.Palette.primary,
                label: "Carbs",
                grams: targets.carbsGoalGrams,
                percent: carbsPct
            )
            MacroTile(
                color: Tokens.Palette.warning,
                label: "Fat",
                grams: targets.fatGoalGrams,
                percent: fatPct
            )
        }
    }
}

private struct MacroTile: View {
    let color: Color
    let label: LocalizedStringKey
    let grams: Int
    let percent: Int

    var body: some View {
        VStack(spacing: Tokens.Space.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Text("\(percent)%")
                    .font(Tokens.Font.footnote.weight(.bold))
                    .foregroundStyle(color)
            }
            Text("\(grams) g")
                .font(Tokens.Font.body.weight(.semibold))
                .foregroundStyle(Tokens.Palette.ink)
            Text(label)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }
}

// MARK: - Secondary metrics row (water + fiber)

private struct SecondaryMetricsRow: View {
    let targets: GoalCalculator.Targets

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            SecondaryChip(
                symbol: "drop.fill",
                color: Color(red: 0.35, green: 0.62, blue: 0.85),
                value: "\(targets.waterGoalMl) ml",
                label: "Woda"
            )
            SecondaryChip(
                symbol: "leaf.fill",
                color: Tokens.Palette.success,
                value: "\(targets.fiberGoalGrams) g",
                label: "Fiber"
            )
        }
    }
}

private struct SecondaryChip: View {
    let symbol: String
    let color: Color
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(label)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }
}

// MARK: - Ola's plan card

private struct OlaPlanCard: View {
    let recommendations: Recommendations

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            OlaHeader()

            Text(L(recommendations.summary))
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)

            if !recommendations.warnings.isEmpty {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    ForEach(recommendations.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Tokens.Palette.warning)
                                .frame(width: 16)
                            Text(L(warning))
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                }
                .padding(Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.warning.opacity(0.08))
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
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(width: 16)
                    Text(L(recommendations.nextSteps))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 2)
            }
        }
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }
}

private struct OlaHeader: View {
    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Palette.accent, Tokens.Palette.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("Your plan from Ola")
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Personalised tips")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
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
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(L(tip.title))
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L(tip.description))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
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
        .padding(Tokens.Space.lg)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }
}
