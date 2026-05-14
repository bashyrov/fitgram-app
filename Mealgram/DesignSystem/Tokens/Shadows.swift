import SwiftUI

extension Tokens {
    /// A single drop-shadow recipe (color + radius + offset).
    struct ShadowStyle: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Soft, but *present* drop shadows. Cards lift off the canvas just
    /// enough that the eye can scan the hierarchy at a glance.
    enum Shadow {
        static let card = ShadowStyle(
            color: Color.black.opacity(0.06),
            radius: 14,
            x: 0,
            y: 4
        )

        static let float = ShadowStyle(
            color: Color.black.opacity(0.09),
            radius: 20,
            x: 0,
            y: 8
        )

        static let modal = ShadowStyle(
            color: Color.black.opacity(0.14),
            radius: 28,
            x: 0,
            y: 12
        )
    }
}

extension View {
    /// Convenience to apply a Mealgram shadow style.
    func mealgramShadow(_ style: Tokens.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
