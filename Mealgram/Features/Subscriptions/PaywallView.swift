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
                VStack(spacing: Tokens.Space.lg) {
                    header
                    benefitList
                    PaywallComparisonSection()
                    planSection
                    if let errorMessage {
                        PaywallErrorCard(message: errorMessage)
                    }
                    PaywallTrustSection()
                    legalNote
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.lg)
                .padding(.bottom, 116)
            }
            .background(paywallBackground)
            .navigationTitle(Text("Mealgram Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Później", action: onSkip)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Przywróć") { Task { await restore() } }
                        .disabled(isPurchasing)
                }
            }
            .safeAreaInset(edge: .bottom) {
                ctaBar
            }
        }
        .task { await load() }
    }

    private var selectedOffering: SubscriptionOffering? {
        guard let selectedID else { return nil }
        return offerings.first { $0.id == selectedID }
    }

    private var paywallBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.48))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: -160, y: -230)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.26))
                .frame(width: 320, height: 320)
                .blur(radius: 115)
                .offset(x: 170, y: -20)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 105)
                .offset(x: -100, y: 430)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 76, height: 76)
                    .overlay {
                        Image(systemName: "sparkles")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .shadow(color: Tokens.Palette.primary.opacity(0.22), radius: 18, x: 0, y: 10)
                Spacer()
                Text("7 dni free")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Tokens.Palette.primarySoft))
            }

            VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                Text("Odblokuj pełny Mealgram")
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Przez tydzień testujesz Pro bez ryzyka: nielimitowane AI, Ola, przepisy i pełna historia.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(.white.opacity(0.38), lineWidth: 1))
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Co dostajesz w Pro")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: 0) {
                benefitRow(symbol: "camera.viewfinder", text: "Nieograniczone skany, głos i odświeżanie AI")
                Divider().padding(.leading, 48)
                benefitRow(symbol: "sparkles", text: "Ola: porady, pamięć i historia rekomendacji")
                Divider().padding(.leading, 48)
                benefitRow(symbol: "book.pages.fill", text: "Nielimitowane przepisy i pełna biblioteka")
                Divider().padding(.leading, 48)
                benefitRow(symbol: "chart.line.uptrend.xyaxis", text: "Pełna historia, eksporty i cele bez limitów")
            }
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Tokens.Palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Tokens.Palette.separator.opacity(0.65), lineWidth: 0.5)
            }
        }
    }

    private func benefitRow(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28, height: 28)
            Text(text)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.md)
    }

    @ViewBuilder
    private var planSection: some View {
        if isLoading {
            VStack(spacing: Tokens.Space.md) {
                ProgressView()
                    .tint(Tokens.Palette.primary)
                Text("Ładowanie planów…")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.xxl)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tokens.Palette.surface)
            }
        } else if offerings.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Plany testowe są gotowe")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Jeśli Apple chwilowo nie zwróci produktów, pokażemy lokalną konfigurację do sprawdzenia paywalla."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                Button("Pokaż plany testowe") {
                    offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
                    selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
                    errorMessage = nil
                }
                .font(Tokens.Font.footnote.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(Tokens.Space.xl)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tokens.Palette.surface)
            }
        } else {
            VStack(spacing: Tokens.Space.sm) {
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
        }
    }

    private var legalNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Bezpieczna płatność przez Apple", systemImage: "lock.shield.fill")
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(autoRenewalDisclosure)
                .font(Tokens.Font.caption2)
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var autoRenewalDisclosure: LocalizedStringKey {
        """
        Premium odnawia się automatycznie w pokazanej cenie do momentu anulowania. \
        Zarządzaj subskrypcją w Ustawieniach iOS > Apple ID > Subskrypcje.
        """
    }

    private var ctaBar: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(
                title: selectedOffering?.trialDays == nil ? "Dalej" : "Zacznij okres próbny",
                systemImage: "checkmark",
                isLoading: isPurchasing,
                isEnabled: selectedOffering != nil && !isLoading
            ) {
                Task { await purchase() }
            }
            Button("Kontynuuj bez Premium", action: onSkip)
                .font(Tokens.Font.footnote.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.sm)
        .background(.regularMaterial)
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

    private func friendlyBillingError(_ error: Error, fallback: String) -> String {
        let raw = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
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

private struct PaywallOfferingRow: View {
    let offering: SubscriptionOffering
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    HStack(spacing: Tokens.Space.xs) {
                        Text(offering.title)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        if offering.isFeatured {
                            Text("NAJLEPSZA")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Tokens.Palette.primary))
                        }
                    }
                    Text(detail)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: Tokens.Space.sm)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(offering.priceLabel)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(offering.periodLabel)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? Tokens.Palette.primary : Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.lg)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Tokens.Palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected ? Tokens.Palette.primary : Tokens.Palette.separator.opacity(0.65),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            }
        }
        .buttonStyle(.plain)
    }

    private var detail: LocalizedStringKey {
        if let trialDays = offering.trialDays {
            return LocalizedStringKey(
                String.localizedStringWithFormat(L("%lld dni za darmo"), trialDays)
            )
        }
        return "Anuluj kiedy chcesz"
    }
}
