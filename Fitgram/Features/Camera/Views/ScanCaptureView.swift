import SwiftUI

/// Live camera preview + overlay + shutter button. Reads its state from
/// `ScanState` so the same view supports the capturing → processing
/// transition.
struct ScanCaptureView: View {
    @Bindable var state: ScanState
    let session: CameraCaptureSession
    let onCancel: () -> Void
    /// Mockup top-right pill "✦ AI · 3 / 5 dziś"; hidden when the plan has no daily photo cap.
    var quotaText: String?
    @State private var progressPhase = 0

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
                    stepPill(activePhase: isProcessing ? progressPhase : 0)
                    ShutterButton(isBusy: isBusy) {
                        Task { await state.capturePhoto() }
                    }
                }
                .padding(.bottom, 40)
            }

            if isProcessing {
                scanProgressOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .onAppear { startProgressAnimation() }
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

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Tokens.Mono.heroLine, lineWidth: 10)
                        .frame(width: 92, height: 92)
                    Circle()
                        .trim(from: 0, to: CGFloat(progressValue))
                        .stroke(Tokens.Mono.hi, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 92, height: 92)
                        .rotationEffect(.degrees(-90))
                    Image(systemName: progressIcon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(Tokens.Mono.hi)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(spacing: 6) {
                    Text(progressTitle)
                        .font(Tokens.Font.monoDisplay(22))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                        .multilineTextAlignment(.center)
                    Text(progressSubtitle)
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .multilineTextAlignment(.center)
                }

                stepPill(activePhase: progressPhase)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
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
