import SwiftUI

extension Tokens {
    /// Brand palette. All values resolve to colors registered in the asset catalog,
    /// so they automatically adapt to light / dark appearance.
    enum Palette {
        // Canvas
        static let background = Color("BrandBackground")
        static let surface = Color("BrandSurface")
        static let surfaceMuted = Color("BrandSurfaceMuted")

        // Brand
        static let primary = Color("BrandPrimary")
        static let primarySoft = Color("BrandPrimarySoft")
        static let accent = Color("BrandAccent")
        static let accentSoft = Color("BrandAccentSoft")

        // Text
        static let ink = Color("BrandInk")
        static let inkMuted = Color("BrandInkMuted")
        static let inkSubtle = Color("BrandInkSubtle")

        // Structure
        static let separator = Color("BrandSeparator")

        // Status
        static let success = Color("BrandSuccess")
        static let warning = Color("BrandWarning")
        static let error = Color("BrandError")
    }
}
