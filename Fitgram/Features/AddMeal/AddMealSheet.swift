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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                navRow
                MonoH1(
                    text: L("Dodaj posiłek"),
                    sub: L("Każda metoda kończy się jasnym wyborem: ogólnie albo szczegółowo")
                )
                .padding(.horizontal, Tokens.Space.screenPadding)

                scanButton
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, 18)
                    .addHubStage(isVisible: hasAppeared, index: 0)

                olaChefBlock
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, 8)
                    .addHubStage(isVisible: hasAppeared, index: 1)

                quickActionGrid
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, 8)
                    .addHubStage(isVisible: hasAppeared, index: 2)

                recentStrip
                    .addHubStage(isVisible: hasAppeared, index: 3)
            }
            .padding(.bottom, 34)
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
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
    /// `nav('', 'Zamknij')` — muted text action on the left, no title.
    private var navRow: some View {
        HStack {
            MonoNavText(title: L("Zamknij"), action: onCancel)
                .frame(height: 44)
                .accessibilityLabel(L("Zamknij"))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(minHeight: 52)
    }

    private var quickActionGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8),
            ],
            spacing: 8
        ) {
            AddMealMiniActionCard(
                icon: "mic",
                tint: Tokens.Palette.lime,
                title: "Głos",
                subtitle: "Powiedz posiłek",
                quota: quotaLabel(
                    used: usageMeter.used(.voiceEntry),
                    cap: entitlementsStore.current.aiActionsPerWeek
                )
            ) {
                run(onVoice)
            }

            AddMealMiniActionCard(
                icon: "pencil",
                tint: Tokens.Palette.accent,
                title: "Ręcznie",
                subtitle: "Pełna kontrola",
                quota: .unlimited
            ) {
                run(onManual)
            }

            AddMealMiniActionCard(
                icon: "books.vertical",
                tint: Tokens.Palette.primary,
                title: "Baza",
                subtitle: "Nasza baza dań · 300+ klasycznych dań",
                quota: .unlimited
            ) {
                run(onQuickDB)
            }

            AddMealMiniActionCard(
                icon: "book.closed",
                tint: Tokens.Palette.warning,
                title: "Przepis",
                subtitle: "Z biblioteki",
                quota: .unlimited
            ) {
                run(onRecipe)
            }
        }
    }

    /// `sec('', 'Jeszcze szybciej', mt 24)` + two outline pills.
    private var recentStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoSectionHeader(title: L("Jeszcze szybciej"))
                .padding(.horizontal, 18)
                .padding(.top, 24 - Tokens.Space.lg)

            HStack(spacing: 8) {
                AddMealCompactPill(
                    icon: "barcode",
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
                    icon: "clock",
                    tint: Tokens.Palette.primary,
                    title: "Ostatnie",
                    quota: .unlimited
                ) {
                    run(onRecentMeal)
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    private func run(_ action: @escaping () -> Void) {
        Haptics.light()
        action()
    }

    /// Dark hero button: hi icon box 56, display title + AI tag, muted sub, quota pill, chevron.
    private var scanButton: some View {
        Button {
            run(onPhotoScan)
        } label: {
            HStack(spacing: 14) {
                MonoIconBox(systemName: "camera", style: .hi, size: 56)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(L("Skanuj zdjęciem"))
                            .font(Tokens.Font.monoDisplay(22))
                            .textCase(.uppercase)
                            .foregroundStyle(Tokens.Mono.onHero)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .bold))
                            Text("AI")
                                .font(Tokens.Font.manrope(11, weight: 800))
                        }
                        .foregroundStyle(Tokens.Mono.onHi)
                        .padding(.horizontal, 8)
                        .frame(height: 22)
                        .background(Capsule().fill(Tokens.Mono.hi))
                    }
                    Text(L("AI rozpozna danie i pokaże tryb ogólny albo detale"))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if photoQuota.label != nil {
                        AddMealQuotaBadge(
                            quota: photoQuota,
                            isProminent: true,
                            foreground: Tokens.Mono.onHero,
                            background: Tokens.Mono.heroLine
                        )
                        .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Mono.onHero)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous))
        }
        .buttonStyle(.pressable)
    }

    /// Accent "Kuchnia Oli" button: fork icon, Archivo title, onAccentSub copy, chevron.
    private var olaChefBlock: some View {
        Button {
            run(onOlaChef)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "fork.knife")
                    .font(.system(size: 24, weight: .medium))
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Kuchnia Oli"))
                        .font(Tokens.Font.archivo(size: 17, weight: 800, width: 115))
                    Text(L("Wybierz kalorie, a Ola dobierze danie, porcję, składniki i przepis."))
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.onAccentSub)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .foregroundStyle(Tokens.Mono.onAccent)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Tokens.Mono.accent)
            )
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

// MARK: - Quota
extension AddMealSheet {
    private var photoQuota: AddMealQuota {
        quotaLabel(
            used: usageMeter.used(.photoScan),
            cap: entitlementsStore.current.aiActionsPerWeek
        )
    }

    private func quotaLabel(used: Int, cap: Int?) -> AddMealQuota {
        guard let cap else { return .unlimited }
        return .limited(used: used, cap: cap)
    }
}
