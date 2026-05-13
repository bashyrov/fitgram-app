import SwiftUI

/// Last "review your plan" screen before the user lands in the app.
/// Doubles as: photo-scan reference picker + full computed plan +
/// AI-Ola recommendations.
struct CalibrationStepView: View {
    @Binding var profile: OnboardingProfile
    var computedTargets: GoalCalculator.Targets?
    var recommendations: Recommendations?
    var isLoadingRecommendations: Bool
    let onContinue: () -> Void

    @State private var reference: ReferenceObjectKind = .creditCard

    var body: some View {
        OnboardingStepScaffold(
            title: "Twój plan",
            subtitle: "Możesz to wszystko zmienić później w Profilu.",
            primaryTitle: "Zatwierdź",
            primarySystemImage: "checkmark",
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.lg) {
                    if let computedTargets {
                        planCard(computedTargets)
                    }
                    recommendationsCard
                    referenceSection
                }
            }
        )
    }

    private func planCard(_ targets: GoalCalculator.Targets) -> some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Twoja dzienna norma")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                    Spacer()
                    if targets.hitSafetyFloor {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Tokens.Palette.warning)
                    }
                }
                Text("🔥 \(targets.dailyCalorieGoalKcal) kcal")
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                Divider()
                planRow(symbol: "💪", label: "Białko", value: "\(targets.proteinGoalGrams) g")
                planRow(symbol: "🥑", label: "Tłuszcze", value: "\(targets.fatGoalGrams) g")
                planRow(symbol: "🍞", label: "Węglowodany", value: "\(targets.carbsGoalGrams) g")
                planRow(symbol: "🌾", label: "Błonnik", value: "\(targets.fiberGoalGrams) g")
                planRow(symbol: "💧", label: "Woda", value: "\(targets.waterGoalMl) ml")
            }
        }
    }

    private func planRow(symbol: String, label: String, value: String) -> some View {
        HStack {
            Text("\(symbol) \(label)")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Text(value)
                .font(Tokens.Font.body.weight(.semibold))
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    @ViewBuilder
    private var recommendationsCard: some View {
        if let recommendations {
            Card(background: Tokens.Palette.surface) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Label("Od Oli", systemImage: "sparkles")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.accent)
                    Text(recommendations.summary)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                    ForEach(recommendations.warnings, id: \.self) { warning in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Tokens.Palette.warning)
                            Text(warning)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                    Divider()
                    ForEach(recommendations.tips) { tip in
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(tip.icon)
                                Text(tip.title)
                                    .font(Tokens.Font.body.weight(.semibold))
                                    .foregroundStyle(Tokens.Palette.ink)
                            }
                            Text(tip.description)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                    }
                    if !recommendations.nextSteps.isEmpty {
                        Divider()
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Tokens.Palette.primary)
                            Text(recommendations.nextSteps)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.ink)
                        }
                    }
                }
            }
        } else if isLoadingRecommendations {
            Card(background: Tokens.Palette.surface) {
                HStack(spacing: Tokens.Space.sm) {
                    ProgressView()
                    Text("Ola przygotowuje Twoje wskazówki…")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Punkt odniesienia do skanu zdjęć")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            OnboardingChoiceCard(
                symbol: "creditcard.fill",
                title: "Karta płatnicza",
                subtitle: "Najczęściej wybierany punkt odniesienia",
                isSelected: reference == .creditCard,
                action: { reference = .creditCard }
            )
            OnboardingChoiceCard(
                symbol: "hand.raised.fill",
                title: "Twoja dłoń",
                subtitle: "Naturalnie zawsze pod ręką",
                isSelected: reference == .eatingHand,
                action: { reference = .eatingHand }
            )
            OnboardingChoiceCard(
                symbol: "fork.knife",
                title: "Sztućce",
                subtitle: "Łyżka, widelec — porównujemy z talerzem",
                isSelected: reference == .fork,
                action: { reference = .fork }
            )
        }
    }
}
