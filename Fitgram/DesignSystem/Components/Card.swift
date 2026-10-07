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
            .background(
                // Design D: every card is the same flat surface; tinted backgrounds are ignored.
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
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
        Card(background: Tokens.Mono.track, elevation: Tokens.Shadow.float) {
            Text("Wskazówka od Oli ✨")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
