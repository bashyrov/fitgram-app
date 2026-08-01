import SwiftUI

/// A soft, rounded container used for grouping content (today's meals,
/// progress, AI insight bubbles, etc.). Avoid stacking cards on cards — keep
/// the layout breathing.
struct Card<Content: View>: View {
    var padding: CGFloat = Tokens.Space.lg
    var background: Color = Tokens.Palette.surface
    var elevation: Tokens.ShadowStyle = Tokens.Shadow.card
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(background.opacity(0.84))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.36), lineWidth: 1)
            )
            .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 18, y: 10)
    }
}

#Preview("Card") {
    VStack(spacing: Tokens.Space.lg) {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Dzisiaj")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("1 240 / 2 100 kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
            }
        }
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.float) {
            Text("Wskazówka od Oli ✨")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
