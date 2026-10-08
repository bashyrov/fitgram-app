import SwiftUI

/// Universal in-app upgrade sheet. It uses the active SubscriptionService
/// offerings so the UI mirrors the StoreKit configuration exactly.
struct UpgradeSheet: View {
    let trigger: PaywallTrigger
    let subscriptionService: any SubscriptionService
    let onDismiss: () -> Void

    @State private var offerings: [SubscriptionOffering] = []
    @State private var selectedID: String?
    @State private var isLoading = true
    @State private var isPurchasing = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    triggerContext
                        .padding(.top, 6)
                    PaywallHero(trialDays: selectedOffering?.trialDays)
                        .padding(.top, 12)
                    PaywallBenefitList()
                    PaywallSectionTitle(title: L("Wybierz plan"))
                    planSection
                    if let error {
                        Text(error)
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.danger)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
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
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Premium"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(Text(L("Później")))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavText(title: L("Przywróć"), emphasized: true) { Task { await restore() } }
                        .disabled(isPurchasing)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                bottomBar
            }
        }
        .task { await loadOfferings() }
        .toastSurface()
    }

    private var selectedOffering: SubscriptionOffering? {
        guard let selectedID else { return nil }
        return offerings.first { $0.id == selectedID }
    }

    /// Why the sheet opened ("Daily AI limit used …") — a compact card above
    /// the shared selling hero.
    private var triggerContext: some View {
        let copy = trigger.copy
        return HStack(alignment: .top, spacing: 12) {
            MonoIconBox(systemName: "bolt.fill", style: .accent, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(copy.headline)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(copy.body)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 14)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var planSection: some View {
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
                Text(
                    "Apple może nie zwrócić produktów w lokalnej instalacji. Do testu pokażemy konfigurację z aplikacji."
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
                MonoButton(title: L("Pokaż plany testowe"), kind: .outline, height: 44) {
                    offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
                    selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
                    error = nil
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

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bezpieczna płatność przez Apple", systemImage: "lock")
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
            Text(autoRenewalDisclosure)
                .font(Tokens.Font.manrope(11, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let privacyURL {
                    Link("Polityka prywatności", destination: privacyURL)
                }
                Text(verbatim: "·")
                    .foregroundStyle(Tokens.Mono.muted)
                if let termsURL {
                    Link("Warunki korzystania", destination: termsURL)
                }
                Spacer()
            }
            .font(Tokens.Font.manrope(12, weight: 800))
            .foregroundStyle(Tokens.Palette.ink)
        }
        .padding(.horizontal, 6)
    }

    private var privacyURL: URL? {
        URL(string: "https://fitgram.space/privacy")
    }

    private var termsURL: URL? {
        URL(string: "https://fitgram.space/terms")
    }

    private var bottomBar: some View {
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

            Text(selectedOffering?.paywallCTACaption ?? L("Zarządzaj lub anuluj kiedy chcesz w Ustawieniach"))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    /// Apple App Store guideline 3.1.2 requires clear subscription terms.
    private var autoRenewalDisclosure: LocalizedStringKey {
        """
        Premium odnawia się co miesiąc lub co rok w pokazanej cenie do momentu anulowania. \
        Opłata za odnowienie jest pobierana z Apple ID przed końcem okresu.
        """
    }

    @MainActor
    private func loadOfferings() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let loaded = try await subscriptionService.offerings()
            offerings = loaded
            selectedID = loaded.first(where: \.isFeatured)?.id ?? loaded.first?.id
        } catch {
            offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
            selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
            self.error = nil
        }
    }

    @MainActor
    private func purchase() async {
        guard let selectedOffering, !isPurchasing else { return }
        isPurchasing = true
        error = nil
        defer { isPurchasing = false }
        do {
            let snapshot = try await subscriptionService.purchase(selectedOffering)
            if snapshot.isPremium {
                Haptics.success()
                onDismiss()
            }
        } catch {
            self.error =
                (error as? any LocalizedError)?.errorDescription
                ?? L("Couldn't start the subscription. Please try again.")
        }
    }

    @MainActor
    private func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        error = nil
        defer { isPurchasing = false }
        do {
            let snapshot = try await subscriptionService.restore()
            if snapshot.isPremium {
                Haptics.success()
                onDismiss()
            } else {
                self.error = L("Nothing to restore.")
            }
        } catch {
            self.error = (error as? any LocalizedError)?.errorDescription ?? L("Nothing to restore.")
        }
    }
}
