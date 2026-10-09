import CoreText
import SwiftUI
import UIKit

// MARK: - "Graphite Mono" (design D) colour roles
//
// Variant D uses a dark "hero" surface on every palette, an accent that stays
// readable on top of that hero (`hi`), thin hairlines instead of shadows and
// one warm third colour for fat. Values come from the approved canvas mockups
// (Fitgram — Dziś, row "Wariant D — 7 palet").

struct MonoRoles {
    let hero: Color
    let heroMuted: Color
    let heroLine: Color
    let onHero: Color
    let hi: Color
    let onHi: Color
    let track: Color
    let strong: Color
    let accent: Color
    let onAccent: Color
    let onAccentSub: Color
    let fat: Color
    let line: Color
    let line2: Color
    let muted: Color
}

extension Color {
    /// `0xRRGGBB` → Color. Internal helper for design tokens only.
    fileprivate init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension AppAccentPalette {
    var mono: MonoRoles {
        switch self {
        case .graphiteLime:
            return Self.darkRoles(
                hero: 0x2A2E2C, heroMuted: 0x9AA09C, heroLine: 0x3C413E, onHero: 0xF7F5EF,
                hi: 0xA8DB57, onHi: 0x121414, track: 0x343836, accent: 0xA8DB57, onAccentSub: 0x3B4A1E,
                fat: 0xFF9D60, muted: 0xA3A6A1)
        case .ocean:
            return Self.darkRoles(
                hero: 0x1A2B33, heroMuted: 0x8FA3B1, heroLine: 0x2A3D46, onHero: 0xE8F1F6,
                hi: 0x4FBDE6, onHi: 0x0D1318, track: 0x22333C, accent: 0x4FBDE6, onAccentSub: 0x12384A,
                fat: 0xF5A962, muted: 0x93A5B2)
        case .amber:
            return Self.lightRoles(
                hero: 0x2C3527, heroMuted: 0xA7B19E, heroLine: 0x3F4A39, hi: 0xA8DB57, onHi: 0x171A1C,
                track: 0xE4EBD4, accent: 0x548038, onAccent: 0xFFFFFF, onAccentSub: 0xE3F0D2, fat: 0xD9A55B,
                ink: 0x171A1C, muted: 0x5B6356)
        case .porcelainCoralSky:
            return Self.lightRoles(
                hero: 0x343B50, heroMuted: 0xA5ADC2, heroLine: 0x474F66, hi: 0x8CA8D4, onHi: 0x171A1C,
                track: 0xE2E5EF, accent: 0x8CA8D4, onAccent: 0x171A1C, onAccentSub: 0x2F3E57, fat: 0xEBC999,
                ink: 0x1C2030, muted: 0x5C6273)
        case .matchaCeramic:
            return Self.lightRoles(
                hero: 0x30382B, heroMuted: 0xAAB29F, heroLine: 0x434C3D, hi: 0xA9C98C, onHi: 0x171A1C,
                track: 0xE6E3D3, accent: 0x6B8F52, onAccent: 0xFFFFFF, onAccentSub: 0xE6F0DC, fat: 0xC99A6B,
                ink: 0x171A1C, muted: 0x5E6357)
        case .nordicBerry:
            return Self.lightRoles(
                hero: 0x2D384A, heroMuted: 0x9AA6B8, heroLine: 0x404D61, hi: 0xE7A3C4, onHi: 0x1B2433,
                track: 0xE1E8EF, accent: 0x942E61, onAccent: 0xFFFFFF, onAccentSub: 0xF7D3E4, fat: 0x85A3C2,
                ink: 0x1B1F2A, muted: 0x5B6575)
        default:
            // Citrus White (`.rose`) and every non-selectable legacy palette.
            return Self.lightRoles(
                hero: 0x2C3136, heroMuted: 0xA4AAA6, heroLine: 0x40464C, hi: 0xF3A774, onHi: 0x171A1C,
                track: 0xEEE7DC, accent: 0xEC915A, onAccent: 0x171A1C, onAccentSub: 0x5A2A0C, fat: 0xD9B36C,
                ink: 0x171A1C, muted: 0x5F6366)
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func lightRoles(
        hero: UInt32, heroMuted: UInt32, heroLine: UInt32, hi: UInt32, onHi: UInt32,
        track: UInt32, accent: UInt32, onAccent: UInt32, onAccentSub: UInt32, fat: UInt32,
        ink: UInt32, muted: UInt32
    ) -> MonoRoles {
        MonoRoles(
            hero: Color(rgb: hero), heroMuted: Color(rgb: heroMuted), heroLine: Color(rgb: heroLine),
            onHero: Color(rgb: 0xF7F5EF), hi: Color(rgb: hi), onHi: Color(rgb: onHi),
            track: Color(rgb: track), strong: Color(rgb: hero),
            accent: Color(rgb: accent), onAccent: Color(rgb: onAccent), onAccentSub: Color(rgb: onAccentSub),
            fat: Color(rgb: fat), line: Color(rgb: ink, opacity: 0.07), line2: Color(rgb: ink, opacity: 0.13),
            muted: Color(rgb: muted)
        )
    }

    // swiftlint:disable:next function_parameter_count
    private static func darkRoles(
        hero: UInt32, heroMuted: UInt32, heroLine: UInt32, onHero: UInt32, hi: UInt32, onHi: UInt32,
        track: UInt32, accent: UInt32, onAccentSub: UInt32, fat: UInt32, muted: UInt32
    ) -> MonoRoles {
        MonoRoles(
            hero: Color(rgb: hero), heroMuted: Color(rgb: heroMuted), heroLine: Color(rgb: heroLine),
            onHero: Color(rgb: onHero), hi: Color(rgb: hi), onHi: Color(rgb: onHi),
            track: Color(rgb: track), strong: Color(rgb: onHero),
            accent: Color(rgb: accent), onAccent: Color(rgb: onHi), onAccentSub: Color(rgb: onAccentSub),
            fat: Color(rgb: fat), line: Color(rgb: onHero, opacity: 0.08), line2: Color(rgb: onHero, opacity: 0.16),
            muted: Color(rgb: muted)
        )
    }
}

extension Tokens {
    /// Variant D ("Graphite Mono") roles for the active palette.
    enum Mono {
        static var roles: MonoRoles { AppAccentPalette.current.mono }

        static var hero: Color { roles.hero }
        static var heroMuted: Color { roles.heroMuted }
        static var heroLine: Color { roles.heroLine }
        static var onHero: Color { roles.onHero }
        static var hi: Color { roles.hi }
        static var onHi: Color { roles.onHi }
        static var track: Color { roles.track }
        static var strong: Color { roles.strong }
        static var accent: Color { roles.accent }
        static var onAccent: Color { roles.onAccent }
        static var onAccentSub: Color { roles.onAccentSub }
        static var fat: Color { roles.fat }
        static var line: Color { roles.line }
        static var line2: Color { roles.line2 }
        static var muted: Color { roles.muted }
        /// Ring / ticks colour once the calorie goal is closed.
        static let goalDone = Color(rgb: 0xE3A72F)
        static let danger = Color(rgb: 0xC2412D)
    }
}

extension Tokens.Mono {
    /// Brand screens (splash, sign-in, welcome): dark on dark palettes,
    /// light paper with ink stripes on light ones.
    enum Brand {
        static var isLight: Bool { AppAccentPalette.current.preferredColorScheme == .light }
        static var background: Color { isLight ? Tokens.Palette.background : Tokens.Mono.hero }
        static var text: Color { isLight ? Tokens.Palette.ink : Tokens.Mono.onHero }
        static var muted: Color { isLight ? Tokens.Mono.muted : Tokens.Mono.heroMuted }
        /// The FIT mark: the stronger accent reads better on paper.
        static var logo: Color { isLight ? Tokens.Mono.accent : Tokens.Mono.hi }
    }

    enum Radius {
        static let hero: CGFloat = 26
        static let card: CGFloat = 24
        static let tile: CGFloat = 20
        static let icon: CGFloat = 12
    }
}

// MARK: - Fonts (Archivo variable + Manrope variable)

extension Tokens.Font {
    private static let wghtAxis = 0x7767_6874  // 'wght'
    private static let wdthAxis = 0x7764_7468  // 'wdth'

    private static func variable(_ postScriptName: String, size: CGFloat, axes: [Int: CGFloat]) -> UIFont {
        let variationKey = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
        let descriptor = UIFontDescriptor(fontAttributes: [
            .name: postScriptName,
            variationKey: axes,
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    /// Archivo, the condensed-to-expanded display face of variant D.
    /// `width` 62…125, `weight` 100…900.
    static func archivo(
        size: CGFloat, weight: CGFloat = 800, width: CGFloat = 115, italic: Bool = false
    ) -> SwiftUI.Font {
        let name = italic ? "Archivo-SemiBoldItalic" : "Archivo-SemiBold"
        return SwiftUI.Font(variable(name, size: size, axes: [wghtAxis: weight, wdthAxis: width]))
    }

    /// Big italic numbers (calories, macros, kcal on rows).
    static func monoNumber(_ size: CGFloat) -> SwiftUI.Font {
        archivo(size: size, weight: 900, width: size >= 60 ? 125 : 118, italic: true)
    }

    /// Upper-case italic section titles ("01 OLA").
    static func monoDisplay(_ size: CGFloat) -> SwiftUI.Font {
        archivo(size: size, weight: 900, width: 122, italic: true)
    }

    /// UIKit variant of Archivo (navigation bar, segmented controls).
    static func uiArchivo(size: CGFloat, weight: CGFloat, width: CGFloat, italic: Bool = false) -> UIFont {
        variable(
            italic ? "Archivo-SemiBoldItalic" : "Archivo-SemiBold", size: size,
            axes: [wghtAxis: weight, wdthAxis: width])
    }

    /// UIKit variant of Manrope.
    static func uiManrope(_ size: CGFloat, weight: CGFloat) -> UIFont {
        variable("Manrope-ExtraLight", size: size, axes: [wghtAxis: weight])
    }

    /// Manrope scaled with Dynamic Type for the given text style.
    static func manropeScaled(_ size: CGFloat, weight: CGFloat, style: UIFont.TextStyle) -> SwiftUI.Font {
        let base = variable("Manrope-ExtraLight", size: size, axes: [wghtAxis: weight])
        return SwiftUI.Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    /// Archivo (expanded) scaled with Dynamic Type for the given text style.
    static func archivoScaled(_ size: CGFloat, weight: CGFloat, style: UIFont.TextStyle) -> SwiftUI.Font {
        let base = variable("Archivo-SemiBold", size: size, axes: [wghtAxis: weight, wdthAxis: 115])
        return SwiftUI.Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    /// Manrope body text. `weight` 200…800.
    static func manrope(_ size: CGFloat, weight: CGFloat = 600) -> SwiftUI.Font {
        SwiftUI.Font(variable("Manrope-ExtraLight", size: size, axes: [wghtAxis: weight]))
    }
}

/// UIKit chrome (navigation bars, segmented pickers) in design D typography.
enum MonoAppearance {
    @MainActor
    static func apply() {
        let navigationBar = UINavigationBar.appearance()
        navigationBar.titleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .headline)
                .scaledFont(for: Tokens.Font.uiManrope(15, weight: 800))
        ]
        navigationBar.largeTitleTextAttributes = [
            .font: UIFontMetrics(forTextStyle: .largeTitle)
                .scaledFont(for: Tokens.Font.uiArchivo(size: 32, weight: 900, width: 122, italic: true))
        ]

        UISwitch.appearance().onTintColor = UIColor(Tokens.Mono.accent)

        let segmented = UISegmentedControl.appearance()
        segmented.setTitleTextAttributes([.font: Tokens.Font.uiManrope(13, weight: 700)], for: .normal)
        segmented.setTitleTextAttributes([.font: Tokens.Font.uiManrope(13, weight: 800)], for: .selected)
    }
}
