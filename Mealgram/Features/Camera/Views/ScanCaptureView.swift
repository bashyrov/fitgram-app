import SwiftUI

/// Live camera preview + overlay + shutter button. Reads its state from
/// `ScanState` so the same view supports the capturing → processing
/// transition.
struct ScanCaptureView: View {
    @Bindable var state: ScanState
    let session: CameraCaptureSession
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: session.session)
                .ignoresSafeArea()

            CameraOverlay()

            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(Text("Zamknij aparat"))
                    Spacer()
                    if isProcessing {
                        HStack(spacing: Tokens.Space.sm) {
                            ProgressView().tint(.white)
                            Text("Analizujemy…")
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)

                Spacer()

                ShutterButton(isBusy: isBusy) {
                    Task { await state.capturePhoto() }
                }
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    private var isProcessing: Bool {
        if case .processing = state.stage { return true }
        return false
    }

    private var isBusy: Bool {
        switch state.stage {
        case .capturing, .processing: return true
        default: return false
        }
    }
}
