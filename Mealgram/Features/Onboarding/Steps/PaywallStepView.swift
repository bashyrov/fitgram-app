import SwiftUI

/// Trial-with-card paywall mock. RevenueCat-backed in Milestone 1.10 —
/// for now we render the pricing tiers and treat both CTAs as "finish".
struct PaywallStepView: View {
    let onContinue: () -> Void

    @State private var selectedPlan: Plan = .yearly

    enum Plan: String, CaseIterable, Identifiable {
        case monthly
        case yearly
        case lifetime
        var id: String { rawValue }

        var headline: LocalizedStringKey {
            switch self {
            case .monthly: return "Standard miesięcznie"
            case .yearly: return "Standard rocznie"
            case .lifetime: return "Pioneer Lifetime"
            }
        }
        var price: LocalizedStringKey {
            switch self {
            case .monthly: return "29 zł / mies."
            case .yearly: return "199 zł / rok"
            case .lifetime: return "999 zł raz"
            }
        }
        var detail: LocalizedStringKey {
            switch self {
            case .monthly: return "7 dni próbnych. Anuluj kiedy chcesz."
            case .yearly: return "Oszczędność 43%. 7 dni próbnych."
            case .lifetime: return "Tylko dla pierwszych 1000 użytkowników."
            }
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Wypróbuj Mealgram",
            subtitle: "7 dni za darmo. Bez ukrytych kosztów. Anuluj jednym tapnięciem.",
            primaryTitle: "Zacznij 7-dniowy okres próbny",
            primarySystemImage: "sparkles",
            secondaryTitle: "Kontynuuj bez subskrypcji",
            secondaryAction: onContinue,
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.md) {
                    ForEach(Plan.allCases) { plan in
                        PlanRow(
                            plan: plan,
                            isSelected: selectedPlan == plan,
                            action: { selectedPlan = plan }
                        )
                    }

                    HStack(spacing: Tokens.Space.xs) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Bezpieczna płatność przez Apple. RODO/GDPR od pierwszego dnia.")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    .padding(.top, Tokens.Space.sm)
                }
            }
        )
    }
}

private struct PlanRow: View {
    let plan: PaywallStepView.Plan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.lg) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.headline)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(plan.detail)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Text(plan.price)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(isSelected ? Tokens.Palette.primary : Tokens.Palette.ink)
            }
            .padding(Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(
                        isSelected ? Tokens.Palette.primary : Tokens.Palette.separator,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
