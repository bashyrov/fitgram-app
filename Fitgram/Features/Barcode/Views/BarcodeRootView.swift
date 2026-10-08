import SwiftUI

/// Owns the full barcode-scan lifecycle. Handles permission, capture,
/// lookup, result, error, and not-found stages with the same calm
/// transitions the AI scan uses.
struct BarcodeRootView: View {
    @State private var state: BarcodeFlowState
    /// Kept in @State: the init re-runs on every parent re-render, and a fresh
    /// (unstarted) session would blank the preview while detection kept
    /// running on the first one.
    @State private var session: BarcodeCaptureSession
    /// Barcode whose label the user is photographing after a database miss.
    @State private var labelScan: LabelScanTarget?
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    init(
        captureSession: BarcodeCaptureSession = BarcodeCaptureSession(),
        lookup: any BarcodeLookupService = OpenFoodFactsLookup(),
        mealSaver: any MealSaving,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil,
        mealAnalyzer: MealTextAnalysisService? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self._session = State(initialValue: captureSession)
        self._state = State(
            initialValue: BarcodeFlowState(
                captureSession: captureSession,
                lookup: lookup,
                mealSaver: mealSaver
            )
        )
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self.mealAnalyzer = mealAnalyzer
        self.usageMeter = usageMeter
    }

    var body: some View {
        Group {
            switch state.stage {
            case .checkingPermission:
                splash
            case .needsPermission(let status):
                CameraPermissionView(
                    status: status,
                    onRetry: { Task { await state.start() } },
                    onDismiss: dismiss
                )
            case .scanning, .looking:
                BarcodeScannerView(state: state, session: session, onCancel: dismiss)
            case .result(let product):
                BarcodeProductView(
                    product: product,
                    onSave: { items in
                        do {
                            try state.commit(items: items)
                            dismiss()
                        } catch {
                            state.reset()
                        }
                    },
                    onRetake: { state.reset() },
                    onDismiss: dismiss,
                    favoritesService: favoritesService,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    userRemoteID: userRemoteID,
                    mealAnalyzer: mealAnalyzer,
                    usageMeter: usageMeter
                )
            case .notFound(let code):
                ResultMessageView(
                    symbol: "barcode",
                    title: "Nie znaleźliśmy tego kodu",
                    message: """
                        Kod \(code) nie jest jeszcze w bazie Open Food Facts. \
                        Zrób zdjęcie tabeli wartości odżywczych — odczytamy ją za Ciebie.
                        """,
                    primaryTitle: "Sfotografuj etykietę",
                    onPrimary: {
                        state.stop()
                        labelScan = LabelScanTarget(id: code)
                    },
                    onDismiss: dismiss,
                    primaryIcon: "text.viewfinder",
                    secondaryTitle: "Skanuj jeszcze raz",
                    onSecondary: { state.reset() }
                )
            case .error(let message):
                ResultMessageView(
                    symbol: "exclamationmark.triangle",
                    title: "Something went wrong",
                    message: LocalizedStringKey(message),
                    primaryTitle: "Try again",
                    onPrimary: { Task { await state.start() } },
                    onDismiss: dismiss,
                    primaryIcon: "arrow.clockwise"
                )
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .task { await state.start() }
        .fullScreenCover(item: $labelScan) { target in
            LabelScannerSheet(
                scanner: FoodLabelScanner(),
                onSave: { food in
                    labelScan = nil
                    state.useLabelProduct(food, barcode: target.id)
                },
                onDismiss: { labelScan = nil }
            )
        }
        .onDisappear { state.stop() }
    }

    /// Mockup `Permissions` loading card: track icon box + "Przygotowuję aparat…".
    private var splash: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(title: "", onLeft: dismiss)
            HStack(spacing: 12) {
                MonoIconBox(systemName: "barcode.viewfinder", style: .track, size: 40)
                Text("Preparing the camera…")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer(minLength: 0)
                ProgressView()
                    .tint(Tokens.Mono.muted)
            }
            .monoCard(padding: 16)
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, 10)
            Spacer(minLength: 0)
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
    }

    private func dismiss() {
        state.stop()
        onDismiss()
    }

    private var stageKey: String {
        switch state.stage {
        case .checkingPermission: return "checking"
        case .needsPermission: return "permission"
        case .scanning: return "scanning"
        case .looking(let code): return "looking-\(code)"
        case .result(let product): return "result-\(product.barcode)"
        case .notFound(let code): return "notFound-\(code)"
        case .error: return "error"
        }
    }
}

/// Barcode whose nutrition label is being photographed after a miss.
private struct LabelScanTarget: Identifiable {
    let id: String
}

/// Not-found / error state in the style of the mockup `BarcodeProduct` empty row: track icon box,
/// 15/800 title and muted copy, with the primary action and an outline "Close" at the bottom.
private struct ResultMessageView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let onPrimary: () -> Void
    let onDismiss: () -> Void
    var primaryIcon = "barcode"
    var secondaryTitle: LocalizedStringKey?
    var onSecondary: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(title: "", onLeft: onDismiss)
            HStack(alignment: .center, spacing: 12) {
                MonoIconBox(systemName: symbol, style: .track, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(message)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 30)
            Spacer(minLength: 0)
            MonoBottomBar {
                Button(action: onPrimary) {
                    Label(primaryTitle, systemImage: primaryIcon)
                }
                .buttonStyle(MonoButtonStyle(kind: .dark))
                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Label(secondaryTitle, systemImage: "barcode.viewfinder")
                    }
                    .buttonStyle(MonoButtonStyle(kind: .outline))
                }
                MonoButton(title: L("Close"), kind: .ghost, action: onDismiss)
            }
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
    }
}
