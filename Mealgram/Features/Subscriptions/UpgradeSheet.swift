import SwiftUI

/// Universal in-app upgrade sheet. Raised from any surface that hits a
/// free-tier limit — the `trigger` argument flips the headline/body so
/// the user sees the right framing. Plan selector + purchase wiring
/// uses the same `SubscriptionService` the onboarding paywall does.
struct UpgradeSheet: View {
    let trigger: PaywallTrigger
    let subscriptionService: any SubscriptionService
    let onDismiss: () -> Void

    @State private var selectedPlan: PlanID = .annual
    @State private var isPurchasing: Bool = false
    @State private var error: String?

    enum PlanID: String, CaseIterable, Identifiable {
        case monthly
        case annual
        case lifetime
        var id: String { rawValue }

        var headline: LocalizedStringKey {
            switch self {
            case .monthly: return "Miesięczna"
            case .annual: return "Roczna"
            case .lifetime: return "Pioneer · raz na zawsze"
            }
        }
        var price: LocalizedStringKey {
            switch self {
            case .monthly: return "29 zł"
            case .annual: return "199 zł"
            case .lifetime: return "999 zł"
            }
        }
        var unit: LocalizedStringKey {
            switch self {
            case .monthly: return "/ miesiąc"
            case .annual: return "/ rok"
            case .lifetime: return "jednorazowo"
            }
        }
        var detail: LocalizedStringKey {
            switch self {
            case .monthly: return "7 dni za darmo · anuluj w sekundę"
            case .annual: return "16,60 zł / mies. · 7 dni za darmo"
            case .lifetime: return "Tylko 1000 miejsc · bez subskrypcji"
            }
        }
        var badge: LocalizedStringKey? {
            switch self {
            case .annual: return "−43% TANIEJ"
            case .lifetime: return "LIMITED"
            default: return nil
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        triggerHeader
                        featuresCard
                        plansList
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                        legalNote
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.lg)
                    // Bottom padding clears the floating Primary CTA so
                    // the legal "Bezpieczna płatność..." line is fully
                    // readable when the user scrolls to the end.
                    .padding(.bottom, 130)
                }
                VStack {
                    Spacer()
                    PrimaryButton(
                        title: "Zacznij 7-dniowy okres próbny",
                        systemImage: "sparkles",
                        isLoading: isPurchasing,
                        action: { Task { await purchase() } }
                    )
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.lg)
                    .background(
                        LinearGradient(
                            colors: [Tokens.Palette.background.opacity(0), Tokens.Palette.background],
                            startPoint: .top,
                            endPoint: .center
                        )
                        .frame(height: 32)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .offset(y: -32)
                        .allowsHitTesting(false)
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Później", action: onDismiss)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await restore() }
                    } label: {
                        Text("Przywróć")
                            .font(Tokens.Font.footnote)
                    }
                }
            }
        }
        .toastSurface()
    }

    @ViewBuilder
    private var triggerHeader: some View {
        let copy = trigger.copy
        Card(background: Tokens.Palette.primarySoft) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                if let badge = copy.badge {
                    Text(badge.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(Tokens.Palette.primary)
                        )
                        .foregroundStyle(.white)
                }
                Text(copy.headline)
                    .font(Tokens.Font.title2)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(copy.body)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
    }

    private var featuresCard: some View {
        Card {
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
                    title: "Nieograniczone skany AI",
                    detail: "Zdjęcia, kody, głos — bez tygodniowych limitów"
                )
                feature(
                    symbol: "star.fill",
                    title: "Moje przepisy",
                    detail: "Dodaj jednym tapnięciem, oszczędź minuty dziennie"
                )
                feature(
                    symbol: "sparkles.tv",
                    title: "Ola — Twój trener AI",
                    detail: "Codzienne podsumowania zamiast 1 tygodniowo"
                )
                feature(
                    symbol: "chart.line.uptrend.xyaxis",
                    title: "Pełna historia + eksporty",
                    detail: "JSON, CSV, ZIP · brak limitu 30 dni"
                )
                feature(
                    symbol: "person.2.fill",
                    title: "Nieograniczona społeczność",
                    detail: "Znajomi, cele, przepisy — bez limitów"
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

    private var plansList: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(PlanID.allCases) { plan in
                UpgradePlanRow(
                    plan: plan,
                    isSelected: selectedPlan == plan,
                    action: { selectedPlan = plan }
                )
            }
        }
    }

    private var legalNote: some View {
        VStack(spacing: 4) {
            HStack(spacing: Tokens.Space.xs) {
                Image(systemName: "lock.shield.fill")
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Bezpieczna płatność przez Apple · RODO od pierwszego dnia")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Spacer()
            }
            HStack {
                Text("Anuluj w każdej chwili w Ustawieniach iOS.")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                Spacer()
            }
        }
    }

    // MARK: - Actions

    private func purchase() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let offering = offering(for: selectedPlan)
            _ = try await subscriptionService.purchase(offering)
            Haptics.success()
            onDismiss()
        } catch {
            self.error = "Nie udało się rozpocząć subskrypcji. Spróbuj ponownie."
        }
    }

    private func restore() async {
        do {
            _ = try await subscriptionService.restore()
            Haptics.success()
            onDismiss()
        } catch {
            self.error = "Nic do przywrócenia."
        }
    }

    private func offering(for plan: PlanID) -> SubscriptionOffering {
        switch plan {
        case .monthly: return .stockMonthly
        case .annual: return .stockAnnual
        case .lifetime:
            return SubscriptionOffering(
                id: "lifetime",
                productID: "mealgram_premium_lifetime",
                title: String(localized: "Lifetime"),
                priceLabel: "999 zł",
                periodLabel: String(localized: "jednorazowo"),
                isFeatured: false,
                trialDays: nil
            )
        }
    }
}

private struct UpgradePlanRow: View {
    let plan: UpgradeSheet.PlanID
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
