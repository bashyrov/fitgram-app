import SwiftUI

/// Production paywall — shows offerings from the SubscriptionService,
/// drives purchase + restore flows, surfaces loading and error states.
/// Raise either from onboarding (PaywallStepView wraps this) or as a
/// modal sheet when a feature is gated behind premium.
struct PaywallView: View {
    let service: any SubscriptionService
    let onPurchased: (SubscriptionSnapshot) -> Void
    let onSkip: () -> Void

    @State private var offerings: [SubscriptionOffering] = []
    @State private var selectedID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    header
                    if isLoading {
                        ProgressView()
                            .tint(Tokens.Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Tokens.Space.xxl)
                    } else if offerings.isEmpty {
                        empty
                    } else {
                        VStack(spacing: Tokens.Space.md) {
                            ForEach(offerings) { offering in
                                row(offering)
                            }
                        }
                    }
                    benefits
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.warning)
                            .multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
            VStack {
                Spacer()
                ctaBar
            }
        }
        .task { await load() }
    }

    private var header: some View {
        VStack(spacing: Tokens.Space.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Tokens.Palette.primary)
            Text("Wypróbuj Premium")
                .font(Tokens.Font.title)
                .foregroundStyle(Tokens.Palette.ink)
            Text("7 dni za darmo. Bez ukrytych kosztów. Anuluj jednym tapnięciem.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.lg)
        }
        .padding(.top, Tokens.Space.lg)
    }

    private var benefits: some View {
        VStack(spacing: Tokens.Space.sm) {
            benefitRow(symbol: "infinity", text: "Bez limitów na skany i głos")
            benefitRow(symbol: "sparkles", text: "Trener Ola — pełne podsumowania tygodnia")
            benefitRow(symbol: "chart.line.uptrend.xyaxis", text: "Zaawansowane statystyki i eksport")
            benefitRow(symbol: "heart.fill", text: "Wspierasz polskiego solo-developera")
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.primarySoft.opacity(0.4))
        )
    }

    private func benefitRow(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 24)
            Text(text)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
    }

    private func row(_ offering: SubscriptionOffering) -> some View {
        let isSelected = selectedID == offering.id
        return Button {
            selectedID = offering.id
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text(offering.title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    if offering.isFeatured {
                        Text("NAJLEPSZA OFERTA")
                            .font(Tokens.Font.caption2.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, Tokens.Space.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Tokens.Palette.primary))
                    }
                    Spacer()
                    Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                        .foregroundStyle(isSelected ? Tokens.Palette.primary : Tokens.Palette.inkSubtle)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(offering.priceLabel)
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(offering.periodLabel)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if let trial = offering.trialDays {
                    Text("\(trial) dni za darmo")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
            .padding(Tokens.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .buttonStyle(.plain)
    }

    private var empty: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "exclamationmark.bubble")
                .font(.title)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text("Brak ofert do wyświetlenia.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Button("Spróbuj ponownie") { Task { await load() } }
                .foregroundStyle(Tokens.Palette.primary)
        }
    }

    private var ctaBar: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(
                title: isPurchasing ? "Przetwarzam…" : "Zacznij okres próbny",
                systemImage: "checkmark",
                isEnabled: !isPurchasing && selectedID != nil
            ) {
                Task { await purchase() }
            }
            HStack(spacing: Tokens.Space.lg) {
                Button("Przywróć zakupy") { Task { await restore() } }
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Button("Później", action: onSkip)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                Text("Bezpieczna płatność przez Apple")
            }
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await service.offerings()
            offerings = result
            selectedID = result.first(where: \.isFeatured)?.id ?? result.first?.id
        } catch {
            errorMessage = String(localized: "Nie udało się pobrać ofert. Sprawdź połączenie.")
        }
    }

    @MainActor
    private func purchase() async {
        guard let selectedID,
            let offering = offerings.first(where: { $0.id == selectedID })
        else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let snapshot = try await service.purchase(offering)
            Haptics.success()
            onPurchased(snapshot)
        } catch {
            errorMessage = String(localized: "Zakup nie powiódł się. Spróbuj ponownie.")
        }
    }

    @MainActor
    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let snapshot = try await service.restore()
            if snapshot.isPremium {
                Haptics.success()
                onPurchased(snapshot)
            } else {
                errorMessage = String(localized: "Nie znaleziono aktywnej subskrypcji.")
            }
        } catch {
            errorMessage = String(localized: "Przywracanie nie powiodło się.")
        }
    }
}
