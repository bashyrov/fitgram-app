import SwiftUI

/// Live camera preview + overlay + shutter button. Reads its state from
/// `ScanState` so the same view supports the capturing → processing
/// transition.
struct ScanCaptureView: View {
    @Bindable var state: ScanState
    let session: CameraCaptureSession
    let onCancel: () -> Void
    @State private var progressPhase = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            CameraPreviewView(session: session.session)
                .ignoresSafeArea()
                .brightness(isProcessing ? 0.08 : 0)
                .saturation(isProcessing ? 0.78 : 1)

            CameraOverlay()
                .opacity(isProcessing ? 0.30 : 1)

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
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)

                Spacer()

                ShutterButton(isBusy: isBusy) {
                    Task { await state.capturePhoto() }
                }
                .padding(.bottom, Tokens.Space.xxxl)
            }

            if isProcessing {
                scanProgressOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .onAppear { startProgressAnimation() }
            }
        }
        .animation(Tokens.Motion.gentle, value: isProcessing)
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
            LinearGradient(
                colors: [
                    Color.black.opacity(0.42),
                    Tokens.Palette.primary.opacity(0.20),
                    Color.black.opacity(0.32),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: Tokens.Space.lg) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 12)
                        .frame(width: 92, height: 92)
                    Circle()
                        .trim(from: 0, to: CGFloat(progressValue))
                        .stroke(
                            LinearGradient(
                                colors: [.white, Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 92, height: 92)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: progressIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(spacing: Tokens.Space.xs) {
                    Text(progressTitle)
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(progressSubtitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: Tokens.Space.sm) {
                    progressStep(index: 0, title: "Photo")
                    progressStep(index: 1, title: "Food")
                    progressStep(index: 2, title: "Macros")
                }
            }
            .padding(.horizontal, Tokens.Space.xl)
            .padding(.vertical, Tokens.Space.xl)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(Tokens.Palette.ink.opacity(0.18))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.28), radius: 32, y: 18)
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    private func progressStep(index: Int, title: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(index <= progressPhase ? .white : .white.opacity(0.24))
                .frame(width: 7, height: 7)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(index <= progressPhase ? .white : .white.opacity(0.48))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Capsule().fill(.white.opacity(index <= progressPhase ? 0.16 : 0.08)))
    }

    private var progressValue: Double {
        switch progressPhase {
        case 0: return 0.32
        case 1: return 0.68
        default: return 0.92
        }
    }

    private var progressIcon: String {
        switch progressPhase {
        case 0: return "camera.aperture"
        case 1: return "fork.knife"
        default: return "chart.pie.fill"
        }
    }

    private var progressTitle: LocalizedStringKey {
        switch progressPhase {
        case 0: return "Analizujemy zdjęcie"
        case 1: return "Rozpoznajemy produkty"
        default: return "Liczymy kalorie i makro"
        }
    }

    private var progressSubtitle: LocalizedStringKey {
        switch progressPhase {
        case 0: return "Sprawdzamy kadr i porcję."
        case 1: return "AI szuka składników na talerzu."
        default: return "Za chwilę pokażemy wynik do poprawienia."
        }
    }

    private func startProgressAnimation() {
        progressPhase = 0
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard isProcessing else { return }
            withAnimation(Tokens.Motion.gentle) { progressPhase = 1 }
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard isProcessing else { return }
            withAnimation(Tokens.Motion.gentle) { progressPhase = 2 }
        }
    }
}
