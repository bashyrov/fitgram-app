import AVFoundation
import SwiftUI

/// Live camera preview with a soft scanning reticle. Detected codes flow
/// up through `BarcodeFlowState`; this view just renders.
struct BarcodeScannerView: View {
    @Bindable var state: BarcodeFlowState
    let session: BarcodeCaptureSession
    let onCancel: () -> Void

    /// Mockup `BarcodeScanner`: dark camera, round close button, 300×170 hi frame with a scan line,
    /// the instruction and a "Sprawdzam …" pill while the code is being looked up.
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Barcode scanner: aspect-fit so the user sees the entire
            // camera frame — aspect-fill would crop the edges where a
            // barcode might actually be sitting.
            CameraPreviewView(session: session.session, gravity: .resizeAspect)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.white.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Zamknij skaner"))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .zIndex(1)

                BarcodeReticle(isBusy: isLooking)
                    .padding(.top, 160)

                Text("Skieruj kod kreskowy w środek ramki")
                    .font(Tokens.Font.manrope(15, weight: 700))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 22)

                if isLooking, let code = state.lastBarcode {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold))
                            .symbolEffect(.pulse)
                        Text(String.localizedStringWithFormat(L("Sprawdzam %@"), code))
                            .font(Tokens.Font.manrope(13, weight: 700))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Capsule().fill(Color.white.opacity(0.14)))
                    .padding(.top, 14)
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
            .animation(Tokens.Motion.gentle, value: isLooking)
        }
    }

    private var isLooking: Bool {
        if case .looking = state.stage { return true }
        return false
    }
}

/// 300×170 frame with a 3 pt hi border and a hi scan line; everything around it is dimmed
/// (mockup `box-shadow: 0 0 0 999px rgba(0,0,0,0.4)`).
private struct BarcodeReticle: View {
    let isBusy: Bool

    private let size = CGSize(width: 300, height: 170)

    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .stroke(Tokens.Mono.hi, lineWidth: 3)
            .frame(width: size.width, height: size.height)
            .overlay(
                Rectangle()
                    .fill(Tokens.Mono.hi)
                    .frame(width: size.width - 40, height: 2)
                    .opacity(isBusy ? 0.45 : 1)
                    .animation(Tokens.Motion.gentle, value: isBusy)
            )
            .background(dimming)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var dimming: some View {
        Rectangle()
            .fill(Color.black.opacity(0.4))
            .frame(width: 2400, height: 2400)
            .mask(
                Rectangle()
                    .frame(width: 2400, height: 2400)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .frame(width: size.width, height: size.height)
                            .blendMode(.destinationOut)
                    )
                    .compositingGroup()
            )
    }
}
