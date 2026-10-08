import SwiftUI
import UIKit

/// Live camera preview + overlay + shutter button. Reads its state from
/// `ScanState` so the same view supports the capturing → processing
/// transition.
struct ScanCaptureView: View {
    @Bindable var state: ScanState
    let session: CameraCaptureSession
    let onCancel: () -> Void
    /// Mockup top-right pill "✦ AI · 3 / 5 dziś"; hidden when the plan has no daily photo cap.
    var quotaText: String?

    var body: some View {
        ZStack {
            Color(red: 17 / 255, green: 18 / 255, blue: 20 / 255).ignoresSafeArea()

            CameraPreviewView(session: session.session)
                .ignoresSafeArea()
                .brightness(isProcessing ? 0.08 : 0)
                .saturation(isProcessing ? 0.78 : 1)

            CameraOverlay()
                .opacity(isProcessing ? 0.30 : 1)

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
                    .accessibilityLabel(Text("Zamknij aparat"))
                    Spacer()
                    if let quotaText {
                        quotaPill(quotaText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                VStack(spacing: 22) {
                    stepPill(activePhase: 0)
                    ShutterButton(isBusy: isBusy) {
                        Task { await state.capturePhoto() }
                    }
                }
                .padding(.bottom, 40)
            }

            if isProcessing {
                scanProgressOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(Tokens.Motion.gentle, value: isProcessing)
    }

    private func quotaPill(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(Tokens.Font.manrope(11, weight: 800))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .frame(height: 24)
        .background(Capsule().fill(Color.white.opacity(0.14)))
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

    private var scanProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.45)
                .ignoresSafeArea()
            ScanAnalysisProgressView(image: state.capturedImageData.flatMap(UIImage.init(data:)))
                .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    /// Mockup step pill: "1 · Zdjęcie / 2 · Jedzenie / 3 · Makro" — the active step is a white capsule.
    private func stepPill(activePhase: Int) -> some View {
        HStack(spacing: 6) {
            progressStep(index: 0, title: "Photo", activePhase: activePhase)
            progressStep(index: 1, title: "Food", activePhase: activePhase)
            progressStep(index: 2, title: "Macros", activePhase: activePhase)
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.12)))
    }

    private func progressStep(index: Int, title: LocalizedStringKey, activePhase: Int) -> some View {
        let isActive = index == activePhase
        return (Text(verbatim: "\(index + 1) · ") + Text(title))
            .font(Tokens.Font.manrope(12, weight: isActive ? 800 : 700))
            .foregroundStyle(
                isActive ? Color(red: 17 / 255, green: 18 / 255, blue: 20 / 255) : Color.white.opacity(0.7)
            )
            .lineLimit(1)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isActive ? Color.white : Color.clear)
            )
    }
}
