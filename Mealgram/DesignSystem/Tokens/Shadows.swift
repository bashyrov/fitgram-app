import SwiftUI

extension Tokens {
    /// A single drop-shadow recipe (color + radius + offset).
    struct ShadowStyle: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Editorial-press shadows — minimal, directional, like a magazine
    /// page peeling off the surface. Used sparingly; many cards now
    /// use a 1pt border instead.
    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.04),
            radius: 8,
            x: 0,
            y: 2
        )

        static let float = ShadowStyle(
            color: Color.black.opacity(0.08),
            radius: 16,
            x: 0,
            y: 6
        )

        static let modal = ShadowStyle(
            color: Color.black.opacity(0.18),
            radius: 32,
            x: 0,
            y: 16
        )
    }
}

extension View {
    /// Convenience to apply a Mealgram shadow style.
    func mealgramShadow(_ style: Tokens.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
