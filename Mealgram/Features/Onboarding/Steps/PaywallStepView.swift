import SwiftUI

/// Trial-with-card paywall — three plans, premium features list, social
/// proof line, and a strong primary CTA. RevenueCat-backed in M1.10;
/// for now both CTAs route through `onContinue`.
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
            case .monthly: return "Miesięczna"
            case .yearly: return "Roczna"
            case .lifetime: return "Pioneer · raz na zawsze"
            }
        }
        var price: LocalizedStringKey {
            switch self {
            case .monthly: return "29 zł"
            case .yearly: return "199 zł"
            case .lifetime: return "999 zł"
            }
        }
        var unit: LocalizedStringKey {
            switch self {
            case .monthly: return "/ miesiąc"
            case .yearly: return "/ rok"
            case .lifetime: return "jednorazowo"
            }
        }
        var detail: LocalizedStringKey {
            switch self {
            case .monthly: return "7 dni za darmo · anuluj w sekundę"
            case .yearly: return "16,60 zł / mies. · 7 dni za darmo"
            case .lifetime: return "Tylko 1000 miejsc · bez subskrypcji"
            }
        }
        var badge: LocalizedStringKey? {
            switch self {
            case .yearly: return "−43% TANIEJ"
            case .lifetime: return "LIMITED"
            default: return nil
            }
        }
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "Wypróbuj Mealgram Premium",
            subtitle: "7 dni za darmo. Bez zobowiązań. Anuluj jednym tapnięciem.",
            primaryTitle: "Zacznij 7-dniowy okres próbny",
            primarySystemImage: "sparkles",
            secondaryTitle: "Kontynuuj bez subskrypcji",
            secondaryAction: onContinue,
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.lg) {
                    featuresCard
                    VStack(spacing: Tokens.Space.sm) {
                        ForEach(Plan.allCases) { plan in
                            PlanRow(
                                plan: plan,
                                isSelected: selectedPlan == plan,
                                action: { selectedPlan = plan }
                            )
                        }
                    }
                    socialProof
                    securityNote
                }
            }
        )
    }

    private var featuresCard: some View {
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Tokens.Palette.primary)
                    Text("Co dostajesz w Premium")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                feature(
                    symbol: "camera.metering.center.weighted",
                    title: "Nieograniczone skany zdjęć",
                    detail: "Gemini Pro AI — najdokładniejsze rozpoznawanie polskich dań"
                )
                feature(
                    symbol: "sparkles.tv",
                    title: "Ola — Twój trener AI",
                    detail: "Tygodniowe podsumowania od Claude, dopasowane do Ciebie"
                )
                feature(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Pełna historia + eksporty",
                    detail: "JSON, CSV, ZIP — bez ograniczeń, dla Ciebie i Twojego dietetyka"
                )
                feature(
                    symbol: "person.2.fill",
                    title: "Społeczność znajomych",
                    detail: "Wyzwania, ranking, reakcje — odchudzaj się razem"
                )
            }
        }
    }

    private func feature(
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(detail)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private var socialProof: some View {
        HStack(spacing: Tokens.Space.sm) {
            HStack(spacing: -8) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(avatarColor(index))
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(Tokens.Palette.background, lineWidth: 2))
                }
            }
            Text("Już **2 400+ osób** śledzi swoje cele z Mealgram")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.sm)
    }

    private func avatarColor(_ index: Int) -> Color {
        switch index {
        case 0: return Tokens.Palette.primary
        case 1: return Tokens.Palette.accent
        case 2: return Tokens.Palette.warning
        default: return Tokens.Palette.success
        }
    }

    private var securityNote: some View {
        HStack(spacing: Tokens.Space.xs) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Tokens.Palette.primary)
            Text("Bezpieczna płatność przez Apple · RODO/GDPR od pierwszego dnia")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
        }
    }
}

private struct PlanRow: View {
    let plan: PaywallStepView.Plan
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .stroke(
                            isSelected ? Tokens.Palette.primary : Tokens.Palette.separator,
                            lineWidth: 2
                        )
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle()
                            .fill(Tokens.Palette.primary)
                            .frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Tokens.Space.xs) {
                        Text(plan.headline)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(Tokens.Palette.primary)
                                )
                                .foregroundStyle(.white)
                        }
                    }
                    Text(plan.detail)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 0) {
                    Text(plan.price)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(isSelected ? Tokens.Palette.primary : Tokens.Palette.ink)
                    Text(plan.unit)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            .padding(Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(isSelected ? Tokens.Palette.primarySoft : Tokens.Palette.surface)
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
