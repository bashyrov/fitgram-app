import SwiftUI

extension Tokens {
    /// A single drop-shadow recipe (color + radius + offset).
    struct ShadowStyle: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Soft, low-contrast drop shadows. Avoid heavier elevations — the design is
    /// meant to feel weightless.
    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.04),
            radius: 10,
            x: 0,
            y: 2
        )

        static let float = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 16,
            x: 0,
            y: 4
        )

        static let modal = ShadowStyle(
            color: Color.black.opacity(0.10),
            radius: 24,
            x: 0,
            y: 8
        )
    }
}

extension View {
    /// Convenience to apply a Mealgram shadow style.
    func mealgramShadow(_ style: Tokens.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
