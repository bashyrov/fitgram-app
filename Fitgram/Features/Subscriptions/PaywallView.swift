import SwiftUI

/// Production paywall — loads plans from SubscriptionService, handles
/// purchase / restore, and keeps the presentation close to native iOS.
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
        NavigationStack {
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
                    PaywallComparisonSection()
                    legalNote
                        .padding(.top, 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.lg)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Później"), action: onSkip)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavText(title: L("Przywróć"), emphasized: true) { Task { await restore() } }
                        .disabled(isPurchasing)
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ctaBar
            }
        }
        .task { await load() }
    }

    private var selectedOffering: SubscriptionOffering? {
        guard let selectedID else { return nil }
        return offerings.first { $0.id == selectedID }
    }

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
                    Text(
                        "Jeśli Apple chwilowo nie zwróci produktów, pokażemy lokalną konfigurację do sprawdzenia paywalla."
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    MonoButton(title: L("Pokaż plany testowe"), kind: .outline, height: 44) {
                        offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
                        selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
                        errorMessage = nil
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

            if let ctaCaption = selectedOffering?.paywallCTACaption {
                Text(ctaCaption)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button(action: onSkip) {
                Text("Kontynuuj bez Premium")
            }
            .buttonStyle(MonoButtonStyle(kind: .ghost, height: 40))
        }
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
            offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
            selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
            errorMessage = nil
        }
    }

    @MainActor
    private func purchase() async {
        guard let selectedOffering, !isPurchasing else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let snapshot = try await service.purchase(selectedOffering)
            Haptics.success()
            onPurchased(snapshot)
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
            let snapshot = try await service.restore()
            if snapshot.isPremium {
                Haptics.success()
                onPurchased(snapshot)
            } else {
                errorMessage = L("Nie znaleziono aktywnej subskrypcji.")
            }
        } catch {
            errorMessage = friendlyBillingError(error, fallback: L("Nie znaleźliśmy aktywnego zakupu do przywrócenia."))
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

extension PaywallView {
    fileprivate var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(autoRenewalDisclosure)
                .font(Tokens.Font.manrope(11, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if let termsURL {
                    Link("Terms of Use", destination: termsURL)
                }
                Text(verbatim: "·")
                    .foregroundStyle(Tokens.Mono.muted)
                if let privacyURL {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(Tokens.Font.manrope(12, weight: 800))
            .foregroundStyle(Tokens.Palette.ink)
        }
        .padding(.horizontal, 6)
    }

    fileprivate var autoRenewalDisclosure: LocalizedStringKey {
        """
        Premium odnawia się automatycznie w pokazanej cenie do momentu anulowania. \
        Zarządzaj subskrypcją w Ustawieniach iOS > Apple ID > Subskrypcje.
        """
    }

    fileprivate var termsURL: URL? {
        URL(string: "https://fitgram.space/terms")
    }

    fileprivate var privacyURL: URL? {
        URL(string: "https://fitgram.space/privacy")
    }
}

/// `sec('', title, '', 22)` — display title with hairline, 18 pt text inset.
struct PaywallSectionTitle: View {
    let title: String

    var body: some View {
        MonoSectionHeader(title: title)
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 12)
    }
}

/// Plan card: radio, name + detail, italic price; "NAJLEPSZA" badge on the
/// featured plan; 2 pt ink outline when selected.
struct PaywallOfferingRow: View {
    let offering: SubscriptionOffering
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Circle()
                    .strokeBorder(Tokens.Palette.ink, lineWidth: 2)
                    .background(Circle().fill(isSelected ? Tokens.Palette.ink : Color.clear))
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(Tokens.Palette.surface)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(offering.title)
                        .font(Tokens.Font.manrope(16, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(detail)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Lead with the per-month price so plans compare at a glance.
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offering.perMonthLabel ?? offering.priceLabel)
                        .font(Tokens.Font.monoNumber(22))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(offering.perMonthLabel == nil ? offering.periodLabel : L("/ month"))
                        .font(Tokens.Font.manrope(11, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous)
                    .strokeBorder(isSelected ? Tokens.Palette.ink : Tokens.Mono.line, lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if offering.isFeatured {
                    Text(badgeTitle)
                        .font(Tokens.Font.manrope(10, weight: 800))
                        .tracking(0.8)
                        .foregroundStyle(Tokens.Mono.onAccent)
                        .padding(.horizontal, 8)
                        .frame(height: 20)
                        .background(Capsule().fill(Tokens.Mono.accent))
                        .offset(x: -14, y: -10)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "Best value · −24%" when the savings are known.
    private var badgeTitle: String {
        if let savings = offering.savingsPercent {
            return String.localizedStringWithFormat(L("NAJLEPSZA CENA · −%lld%%"), savings)
        }
        return L("NAJLEPSZA CENA")
    }

    private var detail: String {
        var parts: [String] = []
        if offering.monthlyEquivalentLabel != nil {
            // Annual: the actual charge, since the big number is per month.
            parts.append("\(offering.priceLabel) \(offering.periodLabel)")
        }
        if let trialDays = offering.trialDays {
            parts.append(String.localizedStringWithFormat(L("%lld dni za darmo"), trialDays))
        }
        return parts.isEmpty ? L("Anuluj kiedy chcesz") : parts.joined(separator: " · ")
    }
}
