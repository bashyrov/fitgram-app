import SwiftUI

/// Lightweight shimmer-skeleton placeholder. Use for cards / rows that are
/// fetching data so the user gets a hint that the screen is alive. Capsule
/// shape + soft animated gradient — no images, no CALayer trickery.
struct LoadingShimmer: View {
    var cornerRadius: CGFloat = Tokens.Radius.md
    @State private var phase: CGFloat = -0.6

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Tokens.Palette.surfaceMuted)
            .overlay(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.55), location: 0.5),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: UnitPoint(x: phase, y: 0.5),
                    endPoint: UnitPoint(x: phase + 0.4, y: 0.5)
                )
                .blendMode(.plusLighter)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1.6
                }
            }
            .accessibilityHidden(true)
    }
}

/// Centered pulsing leaf + caption for full-screen loading states.
/// Calmer than a spinner, matches brand voice.
struct LoadingHero: View {
    let title: LocalizedStringKey
    @State private var scale: CGFloat = 0.92
    @State private var opacity: Double = 0.6

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 96, height: 96)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .scaleEffect(scale)
            .opacity(opacity)
            Text(title)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.background)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                scale = 1.05
                opacity = 1
            }
        }
    }
}

#Preview("Skeleton") {
    VStack(spacing: 12) {
        LoadingShimmer().frame(height: 80)
        LoadingShimmer().frame(height: 80)
        LoadingShimmer().frame(height: 80)
    }
    .padding()
    .background(Tokens.Palette.background)
}

#Preview("Hero") {
    LoadingHero(title: "Loading recipes…")
}
