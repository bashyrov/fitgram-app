import SwiftUI

extension Tokens {
    /// Brand palette. All values resolve to colors registered in the asset catalog,
    /// so they automatically adapt to light / dark appearance.
    enum Palette {
        // Canvas
        static var background: Color { AppAccentPalette.current.background }
        static var surface: Color { AppAccentPalette.current.surface }
        static var surfaceMuted: Color { AppAccentPalette.current.surfaceMuted }

        // Brand
        static var primary: Color { AppAccentPalette.current.primary }
        static var primarySoft: Color { AppAccentPalette.current.primarySoft }
        static var accent: Color { AppAccentPalette.current.accent }
        static var accentSoft: Color { AppAccentPalette.current.accentSoft }
        static var onPrimary: Color { AppAccentPalette.current.onPrimary }

        // Text
        static var ink: Color { AppAccentPalette.current.ink }
        static var inkMuted: Color { AppAccentPalette.current.inkMuted }
        static var inkSubtle: Color { AppAccentPalette.current.inkSubtle }

        // Structure
        static var separator: Color { AppAccentPalette.current.separator }

        // Status
        static let success = Color("BrandSuccess")
        static let warning = Color("BrandWarning")
        static let error = Color("BrandError")

        // Fitgram Graphite + Lime anchors.
        static let graphite = Color(red: 0.09, green: 0.10, blue: 0.11)
        static let graphiteSoft = Color(red: 0.14, green: 0.16, blue: 0.17)
        static let warmWhite = Color(red: 0.97, green: 0.96, blue: 0.94)
        static var lime: Color { AppAccentPalette.current.primary }
        static var mutedGreen: Color { AppAccentPalette.current.muted }
    }
}
