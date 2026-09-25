import SwiftUI

/// Owns the full barcode-scan lifecycle. Handles permission, capture,
/// lookup, result, error, and not-found stages with the same calm
/// transitions the AI scan uses.
struct BarcodeRootView: View {
    @State private var state: BarcodeFlowState
    private let session: BarcodeCaptureSession
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
        self.session = captureSession
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
                    symbol: "questionmark.app.dashed",
                    title: "Nie znaleźliśmy tego kodu",
                    message:
                        "Kod \(code) nie jest jeszcze w bazie Open Food Facts. Spróbuj zeskanować inny lub dodaj ręcznie.",
                    primaryTitle: "Skanuj jeszcze raz",
                    onPrimary: { state.reset() },
                    onDismiss: dismiss
                )
            case .error(let message):
                ResultMessageView(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Something went wrong",
                    message: LocalizedStringKey(message),
                    primaryTitle: "Try again",
                    onPrimary: { Task { await state.start() } },
                    onDismiss: dismiss
                )
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .task { await state.start() }
        .onDisappear { state.stop() }
    }

    private var splash: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .tint(Tokens.Palette.primary)
        }
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

private struct ResultMessageView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let primaryTitle: LocalizedStringKey
    let onPrimary: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.xl) {
                Spacer()
                EmptyState(
                    symbol: symbol,
                    title: title,
                    message: message,
                    action: .init(title: primaryTitle, perform: onPrimary)
                )
                Spacer()
                SecondaryButton(title: "Close", systemImage: "xmark", action: onDismiss)
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xl)
            }
        }
    }
}
