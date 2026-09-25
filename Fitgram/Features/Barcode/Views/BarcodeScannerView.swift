import AVFoundation
import SwiftUI

/// Live camera preview with a soft scanning reticle. Detected codes flow
/// up through `BarcodeFlowState`; this view just renders.
struct BarcodeScannerView: View {
    @Bindable var state: BarcodeFlowState
    let session: BarcodeCaptureSession
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Barcode scanner: aspect-fit so the user sees the entire
            // camera frame — aspect-fill would crop the edges where a
            // barcode might actually be sitting.
            CameraPreviewView(session: session.session, gravity: .resizeAspect)
                .ignoresSafeArea()

            ReticleOverlay(isBusy: isLooking)

            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(Text("Zamknij skaner"))
                    Spacer()
                    if isLooking, let code = state.lastBarcode {
                        HStack(spacing: Tokens.Space.sm) {
                            ProgressView().tint(.white)
                            Text(String.localizedStringWithFormat(L("Sprawdzam %@"), code))
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

                Text("Skieruj kod kreskowy w środek ramki")
                    .font(.system(.callout, design: .rounded, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, Tokens.Space.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    private var isLooking: Bool {
        if case .looking = state.stage { return true }
        return false
    }
}

private struct ReticleOverlay: View {
    let isBusy: Bool

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width * 0.82
            let height = width * 0.6
            ZStack {
                Color.black.opacity(0.18)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .frame(width: width, height: height)
                                    .blendMode(.destinationOut)
                            )
                            .compositingGroup()
                    )

                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        isBusy ? Color.white : Color.white.opacity(0.7),
                        lineWidth: isBusy ? 2.5 : 1.5
                    )
                    .frame(width: width, height: height)
                    .animation(Tokens.Motion.gentle, value: isBusy)
            }
        }
        .allowsHitTesting(false)
    }
}
