import SwiftUI

extension Tokens {
    /// A single drop-shadow recipe (color + radius + offset).
    struct ShadowStyle: Equatable {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// Very soft drop shadows. Repeated SwiftUI cards stay visually lifted
    /// without forcing heavy offscreen rendering while scrolling.
    enum Shadow {
        static let card = ShadowStyle(
            color: Color(red: 0.05, green: 0.06, blue: 0.06).opacity(0.026),
            radius: 10,
            x: 0,
            y: 4
        )

        static let float = ShadowStyle(
            color: Color(red: 0.05, green: 0.06, blue: 0.06).opacity(0.052),
            radius: 18,
            x: 0,
            y: 8
        )

        static let modal = ShadowStyle(
            color: Color(red: 0.05, green: 0.06, blue: 0.06).opacity(0.10),
            radius: 26,
            x: 0,
            y: 12
        )
    }
}

extension View {
    /// Convenience to apply a Fitgram shadow style.
    func fitgramShadow(_ style: Tokens.ShadowStyle) -> some View {
        self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
    }
}
