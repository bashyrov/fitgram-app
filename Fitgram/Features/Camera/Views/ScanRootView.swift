import SwiftUI

/// Top-level view of the scan feature — switches between permission ask,
/// capture, processing, and the result screen. Owns the AVCapture session
/// so it can stop the running camera when the user dismisses.
struct ScanRootView: View {
    @State private var state: ScanState
    @State private var didRecordPhotoQuota = false
    /// Kept in @State: the init re-runs on every parent re-render, and a fresh
    /// (unstarted) session would blank the preview while detection kept
    /// running on the first one.
    @State private var session: CameraCaptureSession
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    init(
        captureSession: CameraCaptureSession = CameraCaptureSession(),
        detector: any FoodDetector = MockFoodDetector(),
        mealSaver: any MealSaving,
        photoStore: MealPhotoStore? = nil,
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
            initialValue: ScanState(
                captureSession: captureSession,
                detector: detector,
                mealSaver: mealSaver,
                photoStore: photoStore
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
            case .ready, .capturing, .processing:
                ScanCaptureView(state: state, session: session, onCancel: dismiss, quotaText: photoQuotaText)
            case .results(let result):
                ScanResultView(
                    result: result,
                    imageData: state.capturedImageData,
                    onSave: { result, portion in
                        do {
                            try state.commit(result: result, portionMultiplier: portion)
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
                .onAppear {
                    if result.aiSucceeded {
                        recordPhotoQuotaIfNeeded()
                    }
                }
            case .error(let message):
                ScanErrorView(message: message, onRetry: { Task { await state.start() } }, onDismiss: dismiss)
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .onChange(of: state.stage) { _, newValue in
            if case .results = newValue {
                return
            }
            didRecordPhotoQuota = false
        }
        .task {
            await state.start()
            didRecordPhotoQuota = false
        }
        .onDisappear {
            state.stop()
        }
    }

    /// Mockup `Permissions` loading card: track camera icon box + "Przygotowuję aparat…".
    private var splash: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(
                title: TL(pl: "Uprawnienia", en: "Permissions", uk: "Дозволи", ru: "Разрешения", es: "Permisos"),
                onLeft: dismiss
            )
            HStack(spacing: 12) {
                MonoIconBox(systemName: "camera", style: .track, size: 40)
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

    /// "AI · 3/5 dziś" for the capture pill — remaining / daily cap of photo scans.
    private var photoQuotaText: String? {
        guard let cap = entitlementsStore?.current.aiActionsPerWeek,
            let remaining = usageMeter?.remaining(.photoScan, cap: cap)
        else { return nil }
        let today = TL(pl: "dziś", en: "today", uk: "сьогодні", ru: "сегодня", es: "hoy")
        return "AI · \(remaining) / \(cap) " + today
    }

    private func dismiss() {
        state.stop()
        onDismiss()
    }

    private func recordPhotoQuotaIfNeeded() {
        guard !didRecordPhotoQuota else { return }
        guard let usageMeter, let entitlementsStore else { return }
        let cap = entitlementsStore.current.aiActionsPerWeek
        guard usageMeter.canUse(.photoScan, cap: cap) else { return }
        usageMeter.record(.photoScan, cap: cap)
        didRecordPhotoQuota = true
    }

    private var stageKey: String {
        switch state.stage {
        case .checkingPermission: return "checking"
        case .needsPermission: return "permission"
        case .ready: return "ready"
        case .capturing: return "capturing"
        case .processing: return "processing"
        case .results: return "results"
        case .error: return "error"
        }
    }
}

/// Error state in the design-D message style (track icon box, display title, muted copy) with
/// "Try again" + outline "Close" at the bottom.
private struct ScanErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(title: "", onLeft: onDismiss)
            VStack(spacing: 14) {
                MonoIconBox(systemName: "exclamationmark.triangle", style: .track, size: 72)
                Text("Something went wrong")
                    .font(Tokens.Font.monoDisplay(24))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(message))
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 28)
            .padding(.top, 80)
            Spacer(minLength: 0)
            MonoBottomBar {
                MonoButton(title: L("Try again"), kind: .dark, icon: "arrow.clockwise", action: onRetry)
                MonoButton(title: L("Close"), kind: .outline, action: onDismiss)
            }
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
    }
}
