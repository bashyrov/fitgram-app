import SwiftUI

/// Editorial container — flat surface with a 1pt separator border and
/// a barely-there shadow. Reads like a magazine module rather than a
/// floating chip. Use `.bordered` (default), `.elevated` (for hero
/// surfaces) or `.flat` (no border, no shadow) variants.
struct Card<Content: View>: View {
    enum Variant {
        case bordered, elevated, flat
    }

    var padding: CGFloat = Tokens.Space.lg
    var background: Color = Tokens.Palette.surface
    var elevation: Tokens.ShadowStyle = Tokens.Shadow.card
    var variant: Variant = .bordered
    var cornerRadius: CGFloat = Tokens.Radius.lg
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        variant == .bordered ? Tokens.Palette.separator : Color.clear,
                        lineWidth: 1
                    )
            )
            .mealgramShadow(variant == .elevated ? Tokens.Shadow.float : Tokens.Shadow.card)
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
