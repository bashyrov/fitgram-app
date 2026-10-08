import SwiftUI

/// Onboarding paywall: the same selling hero, benefit list, plan picker and
/// trial timeline as `PaywallView`, with the trial CTA, price caption and
/// "continue without Premium" in the bottom bar. Purchase and restore
/// go through the same StoreKit-backed `SubscriptionService` as
/// `PaywallView`, so the trial flow behaves like every in-app upgrade
/// surface (offerings, purchase, restore, legal disclosure).
struct PaywallStepView: View {
    let subscriptionService: any SubscriptionService
    let onPurchased: () -> Void
    let onSkip: () -> Void

    @State private var offerings: [SubscriptionOffering] = []
    @State private var selectedID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                PaywallHero(trialDays: selectedOffering?.trialDays)
                    .padding(.top, 6)
                PaywallBenefitList()
                planSection
                if let errorMessage {
                    PaywallErrorCard(message: errorMessage)
                        .padding(.top, 12)
                }
                if let trialDays = selectedOffering?.trialDays, let selectedOffering {
                    PaywallTrialTimeline(trialDays: trialDays, offering: selectedOffering)
                }
                legalNote
                    .padding(.top, 16)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Palette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ctaBar
        }
        .task { await load() }
    }

    private var selectedOffering: SubscriptionOffering? {
        guard let selectedID else { return nil }
        return offerings.first { $0.id == selectedID }
    }

    // MARK: - Plans (needed for StoreKit pricing disclosure)

    @ViewBuilder
    private var planSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaywallSectionTitle(title: L("Wybierz plan"))
            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Tokens.Mono.strong)
                    Text("Ładowanie planów…")
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .monoCard(padding: 16)
            } else if offerings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MonoIconBox(systemName: "sparkles", style: .dark, size: 36)
                        Text("Plany testowe są gotowe")
                            .font(Tokens.Font.manrope(14, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    MonoButton(title: L("Pokaż plany testowe"), kind: .outline, height: 44) {
                        showStockOfferings()
                    }
                }
                .monoCard(padding: 16)
            } else {
                VStack(spacing: 12) {
                    ForEach(offerings) { offering in
                        PaywallOfferingRow(
                            offering: offering,
                            isSelected: selectedID == offering.id,
                            action: {
                                selectedID = offering.id
                                Haptics.light()
                            }
                        )
                    }
                }
                // Room for the "NAJLEPSZA" badge that overhangs the top edge.
                .padding(.top, 10)
            }
        }
    }

    // MARK: - Legal + restore

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                """
                Premium odnawia się automatycznie w pokazanej cenie do momentu anulowania. \
                Zarządzaj subskrypcją w Ustawieniach iOS > Apple ID > Subskrypcje.
                """
            )
            .font(Tokens.Font.manrope(11, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let termsURL = URL(string: "https://fitgram.space/terms") {
                    Link("Terms of Use", destination: termsURL)
                }
                Text(verbatim: "·")
                    .foregroundStyle(Tokens.Mono.muted)
                if let privacyURL = URL(string: "https://fitgram.space/privacy") {
                    Link("Privacy Policy", destination: privacyURL)
                }
                Text(verbatim: "·")
                    .foregroundStyle(Tokens.Mono.muted)
                Button {
                    Task { await restore() }
                } label: {
                    Text("Przywróć zakupy")
                }
                .buttonStyle(.plain)
                .disabled(isPurchasing)
            }
            .font(Tokens.Font.manrope(12, weight: 800))
            .foregroundStyle(Tokens.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
    }

    // MARK: - CTA

    private var ctaBar: some View {
        MonoBottomBar {
            Button {
                Task { await purchase() }
            } label: {
                HStack(spacing: 8) {
                    if isPurchasing {
                        ProgressView()
                            .tint(Tokens.Mono.onHero)
                    }
                    Text(SubscriptionOffering.paywallCTATitle(for: selectedOffering))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .buttonStyle(MonoButtonStyle(kind: .dark))
            .disabled(selectedOffering == nil || isLoading || isPurchasing)
            .accessibilityIdentifier(A11yID.Onboarding.paywallContinue)

            if let caption = selectedOffering?.paywallCTACaption {
                Text(caption)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: onSkip) {
                Text("Kontynuuj bez Premium")
            }
            .buttonStyle(MonoButtonStyle(kind: .ghost, height: 40))
            .disabled(isPurchasing)
        }
    }

    // MARK: - Billing

    private func showStockOfferings() {
        offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
        selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
        errorMessage = nil
    }

    @MainActor
    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let result = try await subscriptionService.offerings()
            offerings = result
            selectedID = result.first(where: \.isFeatured)?.id ?? result.first?.id
        } catch {
            showStockOfferings()
        }
    }

    @MainActor
    private func purchase() async {
        guard let selectedOffering, !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            _ = try await subscriptionService.purchase(selectedOffering)
            Haptics.success()
            onPurchased()
        } catch {
            errorMessage = friendlyBillingError(
                error, fallback: L("Spróbuj ponownie za chwilę albo wybierz inny plan."))
        }
    }

    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let snapshot = try await subscriptionService.restore()
            if snapshot.isPremium {
                Haptics.success()
                onPurchased()
            } else {
                errorMessage = L("Nie znaleziono aktywnej subskrypcji.")
            }
        } catch {
            errorMessage = friendlyBillingError(
                error, fallback: L("Nie znaleźliśmy aktywnego zakupu do przywrócenia."))
        }
    }

    private func friendlyBillingError(_ error: any Error, fallback: String) -> String {
        let raw = (error as? any LocalizedError)?.errorDescription ?? error.localizedDescription
        let lower = raw.lowercased()
        if lower.contains("network") || lower.contains("internet") || lower.contains("offline") {
            return L("Połączenie z płatnościami Apple chwilowo nie odpowiedziało. Twoje dane są bezpieczne.")
        }
        if lower.contains("cancel") || lower.contains("anul") {
            return L("Zakup został przerwany. Możesz wrócić do niego w każdej chwili.")
        }
        return fallback
    }
}
