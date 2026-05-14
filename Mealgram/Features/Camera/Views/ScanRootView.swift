import SwiftUI

/// Top-level view of the scan feature — switches between permission ask,
/// capture, processing, and the result screen. Owns the AVCapture session
/// so it can stop the running camera when the user dismisses.
struct ScanRootView: View {
    @State private var state: ScanState
    private let session: CameraCaptureSession
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?

    init(
        captureSession: CameraCaptureSession = CameraCaptureSession(),
        detector: any FoodDetector = MockFoodDetector(),
        mealSaver: MealSaving,
        photoStore: MealPhotoStore? = nil,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil
    ) {
        self.session = captureSession
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
                ScanCaptureView(state: state, session: session, onCancel: dismiss)
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
                    userRemoteID: userRemoteID
                )
            case .error(let message):
                ScanErrorView(message: message, onRetry: { Task { await state.start() } }, onDismiss: dismiss)
            }
        }
        .animation(Tokens.Motion.gentle, value: stageKey)
        .task {
            await state.start()
        }
        .onDisappear {
            state.stop()
        }
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
        case .ready: return "ready"
        case .capturing: return "capturing"
        case .processing: return "processing"
        case .results: return "results"
        case .error: return "error"
        }
    }
}

private struct ScanErrorView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.xl) {
                Spacer()
                EmptyState(
                    symbol: "exclamationmark.triangle.fill",
                    title: "Coś nie zadziałało",
                    message: LocalizedStringKey(message),
                    action: .init(title: "Spróbuj jeszcze raz", perform: onRetry)
                )
                Spacer()
                SecondaryButton(title: "Zamknij", systemImage: "xmark", action: onDismiss)
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.xl)
            }
        }
    }
}
