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
                VStack(spacing: Tokens.Space.lg) {
                    header
                    featuresList
                    planSection
                    if let error {
                        Text(error)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Tokens.Space.lg)
                    }
                    legalNote
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.lg)
                .padding(.bottom, 120)
            }
            .background(upgradeBackground)
            .navigationTitle(Text("Premium"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Później", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Przywróć") { Task { await restore() } }
                        .disabled(isPurchasing)
                }
            }
            .safeAreaInset(edge: .bottom) {
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

    private var upgradeBackground: some View {
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
        let copy = trigger.copy
        return VStack(spacing: Tokens.Space.md) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.primary)
                .frame(width: 74, height: 74)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: Tokens.Palette.primary.opacity(0.22), radius: 18, x: 0, y: 10)

            VStack(spacing: Tokens.Space.xs) {
                if let badge = copy.badge {
                    Text(badge.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Tokens.Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Tokens.Palette.primarySoft))
                }
                Text(copy.headline)
                    .font(Tokens.Font.title2)
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                Text(copy.body)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Tokens.Space.sm)
    }

    private var featuresList: some View {
        VStack(spacing: 0) {
            feature(
                symbol: "camera.viewfinder",
                title: "Nieograniczone skany AI",
                detail: "Zdjęcia, kody i głos bez tygodniowych limitów"
            )
            Divider().padding(.leading, 44)
            feature(
                symbol: "sparkles",
                title: "Ola — Twój coach AI",
                detail: "Codzienne wskazówki i tygodniowe podsumowania pod Twoje cele"
            )
            Divider().padding(.leading, 44)
            feature(
                symbol: "chart.line.uptrend.xyaxis",
                title: "Pełna historia postępów",
                detail: "Trendy, eksporty, przepisy, ulubione i synchronizacja iCloud"
            )
        }
        .padding(.vertical, Tokens.Space.xs)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Tokens.Palette.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Tokens.Palette.separator.opacity(0.65), lineWidth: 0.5)
        }
    }

    private func feature(
        symbol: String,
        title: LocalizedStringKey,
        detail: LocalizedStringKey
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(detail)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                    "Apple może nie zwrócić produktów w lokalnej instalacji. Do testu pokażemy konfigurację z aplikacji."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                Button("Pokaż plany testowe") {
                    offerings = [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
                    selectedID = offerings.first(where: \.isFeatured)?.id ?? offerings.first?.id
                    error = nil
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
                    UpgradeOfferingRow(
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
            HStack(spacing: 14) {
                if let privacyURL {
                    Link("Polityka prywatności", destination: privacyURL)
                }
                if let termsURL {
                    Link("Warunki korzystania", destination: termsURL)
                }
                Spacer()
            }
            .font(Tokens.Font.caption2.weight(.semibold))
            .foregroundStyle(Tokens.Palette.primary)
        }
    }

    private var privacyURL: URL? {
        URL(string: "https://mealgram.xyz/privacy")
    }

    private var termsURL: URL? {
        URL(string: "https://mealgram.xyz/terms")
    }

    private var bottomBar: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(
                title: selectedOffering?.trialDays == nil
                    ? "Dalej"
                    : "Zacznij okres próbny",
                systemImage: "checkmark",
                isLoading: isPurchasing,
                isEnabled: selectedOffering != nil && !isLoading
            ) {
                Task { await purchase() }
            }
            HStack(spacing: Tokens.Space.xs) {
                Image(systemName: "apple.logo")
                Text("Zarządzaj lub anuluj kiedy chcesz w Ustawieniach")
            }
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.sm)
        .background(.regularMaterial)
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
                (error as? LocalizedError)?.errorDescription
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
            self.error = (error as? LocalizedError)?.errorDescription ?? L("Nothing to restore.")
        }
    }
}

private struct UpgradeOfferingRow: View {
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
