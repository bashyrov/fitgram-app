import SwiftUI

/// Premium-feeling iOS action sheet for every meal entry path.
struct AddMealSheet: View {
    let entitlementsStore: EntitlementsStore
    let usageMeter: UsageMeter
    let onPhotoScan: () -> Void
    let onBarcode: () -> Void
    let onQuickDB: () -> Void
    let onRecentMeal: () -> Void
    let onVoice: () -> Void
    let onRecipe: () -> Void
    let onManual: () -> Void
    let onOlaChef: () -> Void
    let onCancel: () -> Void

    @State private var hasAppeared = false
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private var accentPalette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    private var usesDarkActionGradient: Bool {
        accentPalette.preferredColorScheme == .dark
    }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: Tokens.Space.lg) {
                        scanButton
                            .addHubStage(isVisible: hasAppeared, index: 0)

                        olaChefBlock
                            .addHubStage(isVisible: hasAppeared, index: 1)

                        quickActionGrid
                            .addHubStage(isVisible: hasAppeared, index: 2)

                        recentStrip
                            .addHubStage(isVisible: hasAppeared, index: 3)
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.huge)
                }
            }
        }
        .onAppear {
            withAnimation(Tokens.Motion.gentle.delay(0.08)) {
                hasAppeared = true
            }
        }
        .presentationDetents([.height(690), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(Tokens.Radius.xxl)
        .toastSurface()
    }
}

// MARK: - Sections
extension AddMealSheet {
    private var quickActionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: Tokens.Space.sm),
                GridItem(.flexible(), spacing: Tokens.Space.sm),
            ],
            spacing: Tokens.Space.sm
        ) {
            AddMealMiniActionCard(
                icon: "waveform",
                tint: Tokens.Palette.lime,
                title: "Głos",
                subtitle: "Powiedz posiłek",
                quota: quotaLabel(
                    used: usageMeter.used(.voiceEntry),
                    cap: entitlementsStore.current.voiceEntriesPerDay
                )
            ) {
                run(onVoice)
            }

            AddMealMiniActionCard(
                icon: "square.and.pencil",
                tint: Tokens.Palette.accent,
                title: "Ręcznie",
                subtitle: "Pełna kontrola",
                quota: .unlimited
            ) {
                run(onManual)
            }

            AddMealMiniActionCard(
                icon: "magnifyingglass",
                tint: Tokens.Palette.primary,
                title: "Baza",
                subtitle: "Nasza baza dań",
                quota: .unlimited
            ) {
                run(onQuickDB)
            }

            AddMealMiniActionCard(
                icon: "book.pages",
                tint: Tokens.Palette.warning,
                title: "Przepis",
                subtitle: "Z biblioteki",
                quota: .unlimited
            ) {
                run(onRecipe)
            }
        }
    }

    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(L("Jeszcze szybciej"))
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .textCase(.uppercase)
                .padding(.horizontal, Tokens.Space.xs)

            HStack(spacing: Tokens.Space.sm) {
                AddMealCompactPill(
                    icon: "barcode.viewfinder",
                    tint: Tokens.Palette.graphite,
                    title: "Kod",
                    quota: quotaLabel(
                        used: usageMeter.used(.barcodeScan),
                        cap: entitlementsStore.current.barcodeScansPerDay
                    )
                ) {
                    run(onBarcode)
                }
                AddMealCompactPill(
                    icon: "clock.arrow.circlepath",
                    tint: Tokens.Palette.primary,
                    title: "Ostatnie",
                    quota: .unlimited
                ) {
                    run(onRecentMeal)
                }
            }
        }
    }

    private func run(_ action: @escaping () -> Void) {
        Haptics.light()
        action()
    }

    private var background: some View {
        Tokens.Palette.background
            .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(L("Dodaj posiłek"))
                    .font(Tokens.Font.archivo(size: 31, weight: 800, width: 115))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L("Każda metoda kończy się jasnym wyborem: ogólnie albo szczegółowo"))
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel(L("Zamknij"))
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.xl)
        .padding(.bottom, Tokens.Space.lg)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    Tokens.Palette.background.opacity(0),
                    Tokens.Palette.separator.opacity(0.55),
                    Tokens.Palette.background.opacity(0),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 0.6)
            .padding(.horizontal, Tokens.Space.screenPadding)
            .allowsHitTesting(false)
        }
    }

    private var scanButton: some View {
        Button {
            run(onPhotoScan)
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(photoIconBackground)
                        .frame(width: 76, height: 76)
                        .overlay(alignment: .topLeading) {
                            Circle()
                                .fill(.white.opacity(usesDarkActionGradient ? 0.16 : 0.26))
                                .frame(width: 28, height: 28)
                                .blur(radius: 5)
                                .offset(x: 8, y: 8)
                        }
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(primaryActionTextColor)
                }
                .shadow(color: photoGlowColor, radius: 18, y: 10)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("AI")
                            .font(Tokens.Font.manrope(11, weight: 800))
                    }
                    .foregroundStyle(primaryActionTextColor.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(primaryActionTextColor.opacity(usesDarkActionGradient ? 0.14 : 0.20)))

                    Text(L("Skanuj zdjęciem"))
                        .font(Tokens.Font.archivo(size: 24, weight: 800, width: 115))
                        .foregroundStyle(primaryActionTextColor)
                    Text(L("AI rozpozna danie i pokaże tryb ogólny albo detale"))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(primaryActionTextColor.opacity(0.78))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Tokens.Space.sm) {
                    AddMealQuotaBadge(
                        quota: photoQuota,
                        isProminent: true,
                        foreground: primaryActionTextColor,
                        background: primaryActionTextColor.opacity(usesDarkActionGradient ? 0.12 : 0.20)
                    )
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(primaryActionTextColor.opacity(0.86))
                }
            }
            .padding(Tokens.Space.lg)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 154)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        primaryActionGradientStart
                    )
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(usesDarkActionGradient ? 0.14 : 0.30),
                                .white.opacity(0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(lineWidth: 1.1)
                    )
            }
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "sparkle")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(primaryActionTextColor.opacity(0.16))
                    .offset(x: -22, y: -18)
            }
            .shadow(color: primaryActionShadow, radius: 22, y: 12)
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Styling
extension AddMealSheet {
    private var primaryActionTextColor: Color {
        Tokens.Mono.onHero
    }

    private var primaryActionGradientStart: Color {
        Tokens.Mono.hero
    }

    private var primaryActionGradientMiddle: Color {
        usesDarkActionGradient ? Tokens.Palette.surfaceMuted.opacity(0.92) : Tokens.Palette.accent
    }

    private var primaryActionGradientEnd: Color {
        usesDarkActionGradient ? Tokens.Palette.primary.opacity(0.34) : Tokens.Palette.mutedGreen
    }

    private var primaryActionShadow: Color {
        usesDarkActionGradient ? Tokens.Palette.primary.opacity(0.18) : Tokens.Palette.primary.opacity(0.22)
    }

    private var photoIconBackground: Color {
        Tokens.Mono.heroLine
    }

    private var photoGlowColor: Color {
        Color.clear
    }

    private var olaChefBlock: some View {
        Button {
            run(onOlaChef)
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: chefIconGradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Tokens.Mono.hi)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(L("Kuchnia Oli"))
                            .font(Tokens.Font.manrope(21, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                        AddMealQuotaBadge(quota: .unlimited, isProminent: false)
                    }
                    Text(L("Wybierz kalorie, a Ola dobierze danie, porcję, składniki i przepis."))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical.fill")
                        Text(L("300+ klasycznych dań"))
                    }
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .foregroundStyle(Tokens.Mono.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Tokens.Mono.line, lineWidth: 1)
            )
        }
        .buttonStyle(.pressable)
    }

    private var chefIconGradientColors: [Color] {
        [Tokens.Mono.hero, Tokens.Mono.hero]
    }
}

// MARK: - Quota
extension AddMealSheet {
    private var photoQuota: AddMealQuota {
        quotaLabel(
            used: usageMeter.used(.photoScan),
            cap: entitlementsStore.current.photoScansPerDay
        )
    }

    private func quotaLabel(used: Int, cap: Int?) -> AddMealQuota {
        guard let cap else { return .unlimited }
        return .daily(used: used, cap: cap)
    }
}
