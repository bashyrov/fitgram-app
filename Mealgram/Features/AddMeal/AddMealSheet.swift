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

    var body: some View {
        ZStack {
            background
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Tokens.Space.lg) {
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
                    .padding(.bottom, Tokens.Space.xxxl)
                }
                cancelBar
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
                tint: Color(red: 0.86, green: 0.48, blue: 0.28),
                title: "Głos",
                subtitle: "Powiedz posiłek",
                quota: quotaLabel(
                    used: usageMeter.used(.voiceEntry),
                    cap: entitlementsStore.current.voiceEntriesPerWeek
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
            Text("Jeszcze szybciej")
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .textCase(.uppercase)
                .padding(.horizontal, Tokens.Space.xs)

            HStack(spacing: Tokens.Space.sm) {
                AddMealCompactPill(
                    icon: "barcode.viewfinder",
                    tint: Color(red: 0.30, green: 0.45, blue: 0.88),
                    title: "Kod",
                    quota: quotaLabel(
                        used: usageMeter.used(.barcodeScan),
                        cap: entitlementsStore.current.barcodeScansPerWeek
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
        LinearGradient(
            colors: [
                Tokens.Palette.background,
                Tokens.Palette.primarySoft.opacity(0.55),
                Tokens.Palette.accentSoft.opacity(0.42),
                Tokens.Palette.background,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dodaj posiłek")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Każda metoda kończy się jasnym wyborem: ogólnie albo szczegółowo")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
            }
            .buttonStyle(.pressable)
            .accessibilityLabel("Zamknij")
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.xl)
        .padding(.bottom, Tokens.Space.lg)
    }

    private var scanButton: some View {
        Button {
            run(onPhotoScan)
        } label: {
            HStack(spacing: Tokens.Space.lg) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 76, height: 76)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 7) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("AI")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(.white.opacity(0.18)))

                    Text("Skanuj zdjęciem")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("AI rozpozna danie i pokaże tryb ogólny albo detale")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Tokens.Space.sm) {
                    AddMealQuotaBadge(quota: photoQuota, isProminent: true)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
            .padding(Tokens.Space.lg)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 154)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.28, green: 0.62, blue: 0.49),
                                Color(red: 0.17, green: 0.42, blue: 0.36),
                                Color(red: 0.12, green: 0.26, blue: 0.28),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .shadow(color: Color(red: 0.12, green: 0.28, blue: 0.24).opacity(0.28), radius: 24, y: 16)
        }
        .buttonStyle(.pressable)
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
                                colors: [Tokens.Palette.warning.opacity(0.95), Tokens.Palette.primary.opacity(0.82)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "fork.knife.circle.fill")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text("Kuchnia Oli")
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .foregroundStyle(Tokens.Palette.ink)
                        AddMealQuotaBadge(quota: .unlimited, isProminent: false)
                    }
                    Text("Wybierz kalorie, a Ola dobierze danie, porcję, składniki i przepis.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Image(systemName: "books.vertical.fill")
                        Text("300+ klasycznych dań")
                    }
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(Tokens.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84)))
            .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(.white.opacity(0.36), lineWidth: 1))
            .shadow(color: Tokens.Palette.warning.opacity(0.13), radius: 20, y: 12)
        }
        .buttonStyle(.pressable)
    }

    private var cancelBar: some View {
        Button(action: onCancel) {
            Text("Anuluj")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.ultraThinMaterial, in: Capsule())
                .background(Capsule().fill(Tokens.Palette.surface.opacity(0.74)))
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.lg)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.92)
                .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [
                    Tokens.Palette.background.opacity(0),
                    Tokens.Palette.background.opacity(0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 22)
            .offset(y: -22)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
    }

    private var photoQuota: AddMealQuota {
        quotaLabel(
            used: usageMeter.used(.photoScan),
            cap: entitlementsStore.current.photoScansPerWeek
        )
    }

    private func quotaLabel(used: Int, cap: Int?) -> AddMealQuota {
        guard let cap else { return .unlimited }
        return .daily(used: used, cap: cap)
    }
}

private enum AddMealQuota: Equatable {
    case unlimited
    case daily(used: Int, cap: Int)

    var label: String? {
        switch self {
        case .unlimited:
            return nil
        case .daily(let used, let cap):
            return "\(max(0, cap - used))/\(cap)"
        }
    }

    var isExhausted: Bool {
        if case .daily(let used, let cap) = self { return used >= cap }
        return false
    }
}

private struct AddMealMiniActionCard: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let quota: AddMealQuota
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(tint.opacity(0.15))
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(tint)
                    }
                    .frame(width: 52, height: 52)

                    Spacer(minLength: 0)
                    AddMealQuotaBadge(quota: quota, isProminent: false)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(quota.isExhausted ? "Pro" : "Otwórz")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                    Spacer(minLength: 0)
                    Image(systemName: quota.isExhausted ? "lock.fill" : "arrow.up.right")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(quota.isExhausted ? Tokens.Palette.warning : tint)
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.82))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        quota.isExhausted ? Tokens.Palette.warning.opacity(0.42) : .white.opacity(0.34),
                        lineWidth: 1
                    )
            }
            .overlay(alignment: .bottomLeading) {
                Capsule()
                    .fill(tint.opacity(quota.isExhausted ? 0.28 : 0.62))
                    .frame(width: 54, height: 4)
                    .padding(.leading, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.sm)
            }
            .opacity(quota.isExhausted ? 0.78 : 1)
            .shadow(color: tint.opacity(quota.isExhausted ? 0.06 : 0.16), radius: 18, y: 10)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

private struct AddMealCompactPill: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let quota: AddMealQuota
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: quota.isExhausted ? "lock.fill" : icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.14)))
                Text(title)
                    .font(Tokens.Font.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                AddMealQuotaBadge(quota: quota, isProminent: false)
            }
            .padding(.horizontal, Tokens.Space.md)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(.ultraThinMaterial, in: Capsule())
            .background(Capsule().fill(Tokens.Palette.surface.opacity(0.78)))
            .overlay(Capsule().stroke(.white.opacity(0.34), lineWidth: 1))
        }
        .buttonStyle(.pressable)
    }
}

private struct AddHubStageModifier: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.985)
            .animation(Tokens.Motion.gentle.delay(Double(index) * 0.055), value: isVisible)
    }
}

extension View {
    fileprivate func addHubStage(isVisible: Bool, index: Int) -> some View {
        modifier(AddHubStageModifier(isVisible: isVisible, index: index))
    }
}

private struct AddMealQuotaBadge: View {
    let quota: AddMealQuota
    let isProminent: Bool

    var body: some View {
        if let label = quota.label {
            HStack(spacing: 4) {
                if quota.isExhausted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundStyle(isProminent ? .white : Tokens.Palette.inkMuted)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isProminent ? .white.opacity(0.18) : Tokens.Palette.surfaceMuted.opacity(0.88))
            )
        }
    }
}
