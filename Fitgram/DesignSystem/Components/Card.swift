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
            .frostedGlass(
                cornerRadius: 22,
                fillOpacity: 0.70,
                borderOpacity: 0.04,
                glowOpacity: 0.026
            )
            .fitgramShadow(elevation)
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
