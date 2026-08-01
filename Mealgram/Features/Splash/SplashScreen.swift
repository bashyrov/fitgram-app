import SwiftUI

/// Brand splash shown on cold start. A soft sage radial bloom breathes
/// open at the centre of a white canvas; the wordmark rises out of the
/// bloom with a gentle scale + blur release; a single sheen sweep
/// passes diagonally across the letters for a polished-metal feel.
/// No falling pieces, no orbits, no visible mask edges.
struct SplashScreen: View {
    let onComplete: () -> Void

    @State private var bloomScale: CGFloat = 0.4
    @State private var bloomOpacity: Double = 0
    @State private var wordmarkOpacity: Double = 0
    @State private var wordmarkScale: CGFloat = 0.96
    @State private var wordmarkBlur: CGFloat = 8
    @State private var wordmarkOffsetY: CGFloat = 6
    @State private var sheenOffset: CGFloat = -1.4
    @State private var breath: CGFloat = 1.0

    private var wordmarkFont: Font {
        if UIFont.fontNames(forFamilyName: "Agbalumo").first != nil {
            return Font.custom("Agbalumo", size: 56)
        }
        return .system(size: 56, weight: .heavy, design: .rounded)
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            radialBloom

            wordmark
                .opacity(wordmarkOpacity)
                .scaleEffect(wordmarkScale)
                .blur(radius: wordmarkBlur)
                .offset(y: wordmarkOffsetY)
        }
        .onAppear { runAnimation() }
    }

    /// Layered radial gradients give the bloom depth — a tight warm core
    /// inside a soft outer halo. The whole stack breathes via `breath`
    /// so the canvas never feels static.
    private var radialBloom: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tokens.Palette.primary.opacity(0.38),
                            Tokens.Palette.primary.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 220
                    )
                )
                .frame(width: 460, height: 460)
                .blur(radius: 50)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Tokens.Palette.accent.opacity(0.22),
                            Tokens.Palette.accent.opacity(0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 160
                    )
                )
                .frame(width: 320, height: 320)
                .blur(radius: 40)
                .offset(x: -40, y: 30)
        }
        .scaleEffect(bloomScale * breath)
        .opacity(bloomOpacity)
    }

    /// Two stacked Texts: the base ink wordmark + an overlay sheen that
    /// is masked to the text shape so the highlight only shows on the
    /// letters, not the background.
    private var wordmark: some View {
        Text("Mealgram")
            .font(wordmarkFont)
            .foregroundStyle(Tokens.Palette.ink)
            .overlay(sheenOverlay)
    }

    private var sheenOverlay: some View {
        GeometryReader { proxy in
            LinearGradient(
                stops: [
                    .init(color: .white.opacity(0.0), location: 0.0),
                    .init(color: .white.opacity(0.95), location: 0.5),
                    .init(color: .white.opacity(0.0), location: 1.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(width: proxy.size.width * 0.55, height: proxy.size.height * 1.6)
            .rotationEffect(.degrees(20))
            .offset(x: proxy.size.width * sheenOffset, y: 0)
            .blendMode(.plusLighter)
        }
        .mask(
            Text("Mealgram")
                .font(wordmarkFont)
                .foregroundStyle(.black)
        )
        .allowsHitTesting(false)
    }

    private func runAnimation() {
        // 0.00 – 0.80s: bloom opens up from centre.
        withAnimation(.easeOut(duration: 0.8)) {
            bloomScale = 1.0
            bloomOpacity = 1
        }
        // Continuous breathing — gentle pulse for the whole splash.
        withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
            breath = 1.06
        }
        // 0.45 – 1.15s: wordmark rises out of the bloom.
        withAnimation(.easeOut(duration: 0.7).delay(0.45)) {
            wordmarkOpacity = 1
            wordmarkScale = 1
            wordmarkBlur = 0
            wordmarkOffsetY = 0
        }
        // 1.15 – 2.15s: sheen sweeps across once.
        withAnimation(.easeInOut(duration: 1.0).delay(1.15)) {
            sheenOffset = 1.4
        }
        // Total ~2.5s — sheen finishes, then handoff so the wordmark
        // gets a beat to settle without movement.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            onComplete()
        }
    }
}

#Preview {
    SplashScreen(onComplete: {})
}
