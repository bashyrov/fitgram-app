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
                LazyVStack(spacing: Tokens.Space.lg) {
                    header
                    premiumStrip
                    benefitList
                    planSection
                    PaywallComparisonSection()
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
            .navigationTitle(Text("Fitgram Pro"))
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
        ScreenBackground(mood: .warm)
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
            Circle()
                .fill(Tokens.Mono.heroLine)
                .frame(width: 210, height: 210)
                .offset(x: 170, y: -116)
            Circle()
                .fill(Tokens.Mono.heroLine.opacity(0.6))
                .frame(width: 190, height: 190)
                .offset(x: -92, y: 118)

            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .black))
                            Text("FITGRAM PRO")
                                .font(Tokens.Font.manrope(11, weight: 800))
                                .tracking(1.2)
                        }
                        .foregroundStyle(Tokens.Mono.onHi)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Tokens.Mono.hi))

                        Text("7 dni za darmo")
                            .font(Tokens.Font.monoDisplay(38))
                            .foregroundStyle(Tokens.Mono.onHero)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }
                    Spacer(minLength: 0)
                    ZStack {
                        Circle()
                            .fill(Tokens.Mono.hi)
                        Image(systemName: "crown.fill")
                            .font(.system(size: 24, weight: .black))
                            .foregroundStyle(Tokens.Mono.onHi)
                    }
                    .frame(width: 56, height: 56)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pełny AI-coach, bez limitów")
                        .font(Tokens.Font.archivo(size: 24, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Skanuj jedzenie, poprawiaj AI, korzystaj z Oli, przepisów i celów bez dziennych blokad.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Mono.onHero.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
        }
        .frame(minHeight: 290)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous))
    }

    private var premiumStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            premiumMetric(value: "∞", label: "AI")
            premiumMetric(value: L("Ola"), label: "coach")
            premiumMetric(value: "7", label: "dni free")
        }
    }

    private func premiumMetric(value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Tokens.Font.manrope(19, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
            Text(label)
                .font(Tokens.Font.manrope(10, weight: 800))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 66)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.76))
        )
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            Text("W Pro odblokujesz")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                    GridItem(.flexible(), spacing: Tokens.Space.sm),
                ],
                spacing: Tokens.Space.sm
            ) {
                benefitTile(symbol: "camera.viewfinder", title: "AI z dużym limitem", text: "Foto, głos i poprawki")
                benefitTile(symbol: "sparkles", title: "Ola Pro", text: "Porady, pamięć, cele")
                benefitTile(symbol: "book.pages.fill", title: "Przepisy", text: "Biblioteka z dużym limitem")
                benefitTile(symbol: "chart.line.uptrend.xyaxis", title: "Pełny progres", text: "Historia i eksport")
            }
        }
    }

    private func benefitTile(symbol: String, title: LocalizedStringKey, text: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Tokens.Palette.primarySoft.opacity(0.78)))
            Text(title)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(text)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
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
                Text("Wybierz plan")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .background(
            LinearGradient(
                colors: [
                    Tokens.Palette.background.opacity(0),
                    Tokens.Palette.background.opacity(0.96),
                    Tokens.Palette.background,
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
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
            Label("Bezpieczna płatność przez Apple", systemImage: "lock.shield.fill")
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(autoRenewalDisclosure)
                .font(Tokens.Font.caption2)
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: Tokens.Space.md) {
                if let termsURL {
                    Link("Terms of Use", destination: termsURL)
                }
                if let privacyURL {
                    Link("Privacy Policy", destination: privacyURL)
                }
            }
            .font(Tokens.Font.caption.weight(.semibold))
            .foregroundStyle(Tokens.Palette.primary)
        }
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
                                .font(Tokens.Font.manrope(10, weight: 800))
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
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        isSelected
                            ? Tokens.Palette.primarySoft.opacity(0.95)
                            : Tokens.Palette.surface.opacity(0.82)
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isSelected ? Tokens.Palette.primary.opacity(0.32) : .clear,
                        lineWidth: 1
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
