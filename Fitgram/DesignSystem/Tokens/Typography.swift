import SwiftUI

extension Tokens {
    /// Typography scale. SF Pro Rounded everywhere; Dynamic Type respected by
    /// pairing each preset with its closest `Font.TextStyle`.
    enum Font {
        // Design D: Archivo for display sizes, Manrope for text. Both scale with
        // Dynamic Type through `UIFontMetrics` (see MonoTheme.swift).
        static var display: SwiftUI.Font { archivoScaled(34, weight: 800, style: .largeTitle) }
        static var title: SwiftUI.Font { archivoScaled(28, weight: 800, style: .title1) }
        static var title2: SwiftUI.Font { archivoScaled(22, weight: 800, style: .title2) }
        static var title3: SwiftUI.Font { manropeScaled(20, weight: 800, style: .title3) }
        static var headline: SwiftUI.Font { manropeScaled(17, weight: 800, style: .headline) }
        static var body: SwiftUI.Font { manropeScaled(17, weight: 500, style: .body) }
        static var bodyEmphasized: SwiftUI.Font { manropeScaled(17, weight: 700, style: .body) }
        static var callout: SwiftUI.Font { manropeScaled(16, weight: 500, style: .callout) }
        static var subheadline: SwiftUI.Font { manropeScaled(15, weight: 500, style: .subheadline) }
        static var footnote: SwiftUI.Font { manropeScaled(13, weight: 600, style: .footnote) }
        static var caption: SwiftUI.Font { manropeScaled(12, weight: 600, style: .caption1) }
        static var caption2: SwiftUI.Font { manropeScaled(11, weight: 700, style: .caption2) }

        /// Monospaced digits, for calorie counters and timers, keeping width stable.
        static var counter: SwiftUI.Font { monoNumber(44).monospacedDigit() }

        /// Brand display face — Agbalumo Regular. Use for the splash logo and
        /// large hero moments. Falls back to SF Pro Rounded when the bundled
        /// font is missing (e.g. preview canvas before generation).
        static func brand(size: CGFloat) -> SwiftUI.Font {
            SwiftUI.Font.custom("Agbalumo-Regular", size: size, relativeTo: .largeTitle)
        }
    }
}

extension View {
    /// Apply a Fitgram typography preset with sensible defaults (rounded, dynamic).
    func fitgramFont(_ font: SwiftUI.Font) -> some View {
        self.font(font)
    }
}
