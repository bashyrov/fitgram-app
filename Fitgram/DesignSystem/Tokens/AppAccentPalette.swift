import SwiftUI

enum AppAccentPalette: String, CaseIterable, Identifiable {
    static let storageKey = "preferences.accentPalette"

    case graphiteLime
    case ocean
    case rose
    case amber
    case copperBlush
    case copperBlushApricot
    case copperBlushDeep
    case oliveBerry
    case oliveBerryOlive
    case oliveBerryRose
    case porcelainCoral
    case porcelainCoralSky
    case porcelainCoralSand
    case matchaCeramic
    case graphiteMint
    case vanillaBlue
    case cherryCream
    case pistachioInk
    case nordicBerry
    case mochaLime

    var id: String { rawValue }

    static var current: AppAccentPalette {
        let raw = UserDefaults.standard.string(forKey: storageKey)
        guard let palette = raw.flatMap(AppAccentPalette.init(rawValue:)), palette.isSelectable else {
            return .rose
        }
        return palette
    }

    static var selectableCases: [AppAccentPalette] {
        [
            .rose,
            .graphiteLime,
            .ocean,
            .amber,
            .porcelainCoralSky,
            .matchaCeramic,
            .nordicBerry,
        ]
    }

    var isSelectable: Bool {
        Self.selectableCases.contains(self)
    }

    var preferredColorScheme: ColorScheme {
        switch self {
        case .graphiteLime, .ocean: return .dark
        case .rose, .amber, .copperBlush, .copperBlushApricot, .copperBlushDeep,
            .oliveBerry, .oliveBerryOlive, .oliveBerryRose, .porcelainCoral,
            .porcelainCoralSky, .porcelainCoralSand, .matchaCeramic, .vanillaBlue,
            .cherryCream, .nordicBerry:
            return .light
        case .graphiteMint, .pistachioInk, .mochaLime:
            return .dark
        }
    }
}

// MARK: - Colors

extension AppAccentPalette {
    var primary: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.66, green: 0.86, blue: 0.34)
        case .ocean: return Color(red: 0.31, green: 0.74, blue: 0.90)
        case .rose: return Color(red: 0.90, green: 0.46, blue: 0.18)
        case .amber: return Color(red: 0.33, green: 0.50, blue: 0.22)
        case .copperBlush: return Color(red: 0.70, green: 0.25, blue: 0.04)
        case .copperBlushApricot: return Color(red: 0.89, green: 0.43, blue: 0.03)
        case .copperBlushDeep: return Color(red: 0.70, green: 0.25, blue: 0.04)
        case .oliveBerry: return Color(red: 0.88, green: 0.28, blue: 0.36)
        case .oliveBerryOlive: return Color(red: 0.10, green: 0.18, blue: 0.00)
        case .oliveBerryRose: return Color(red: 0.88, green: 0.28, blue: 0.36)
        case .porcelainCoral: return Color(red: 0.95, green: 0.40, blue: 0.35)
        case .porcelainCoralSky: return Color(red: 0.55, green: 0.66, blue: 0.83)
        case .porcelainCoralSand: return Color(red: 0.78, green: 0.58, blue: 0.32)
        case .matchaCeramic: return Color(red: 0.42, green: 0.56, blue: 0.32)
        case .graphiteMint: return Color(red: 0.45, green: 0.86, blue: 0.72)
        case .vanillaBlue: return Color(red: 0.40, green: 0.61, blue: 0.82)
        case .cherryCream: return Color(red: 0.66, green: 0.08, blue: 0.19)
        case .pistachioInk: return Color(red: 0.68, green: 0.82, blue: 0.44)
        case .nordicBerry: return Color(red: 0.58, green: 0.18, blue: 0.38)
        case .mochaLime: return Color(red: 0.72, green: 0.92, blue: 0.32)
        }
    }

    var background: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.070, green: 0.078, blue: 0.080)
        case .ocean: return Color(red: 0.050, green: 0.076, blue: 0.096)
        case .rose: return Color(red: 0.992, green: 0.986, blue: 0.970)
        case .amber: return Color(red: 0.965, green: 0.975, blue: 0.935)
        case .copperBlush: return Color(red: 0.996, green: 0.937, blue: 0.957)
        case .copperBlushApricot: return Color(red: 0.986, green: 0.884, blue: 0.790)
        case .copperBlushDeep: return Color(red: 0.996, green: 0.930, blue: 0.902)
        case .oliveBerry: return Color(red: 0.973, green: 0.937, blue: 0.918)
        case .oliveBerryOlive: return Color(red: 0.973, green: 0.937, blue: 0.918)
        case .oliveBerryRose: return Color(red: 0.988, green: 0.954, blue: 0.948)
        case .porcelainCoral: return Color(red: 0.941, green: 0.937, blue: 0.957)
        case .porcelainCoralSky: return Color(red: 0.941, green: 0.937, blue: 0.957)
        case .porcelainCoralSand: return Color(red: 0.978, green: 0.934, blue: 0.874)
        case .matchaCeramic: return Color(red: 0.963, green: 0.954, blue: 0.918)
        case .graphiteMint: return Color(red: 0.055, green: 0.064, blue: 0.066)
        case .vanillaBlue: return Color(red: 0.988, green: 0.966, blue: 0.900)
        case .cherryCream: return Color(red: 0.996, green: 0.944, blue: 0.910)
        case .pistachioInk: return Color(red: 0.035, green: 0.075, blue: 0.052)
        case .nordicBerry: return Color(red: 0.948, green: 0.964, blue: 0.976)
        case .mochaLime: return Color(red: 0.090, green: 0.070, blue: 0.056)
        }
    }

    var splashBackground: Color {
        switch self {
        case .graphiteLime, .ocean:
            return Color(red: 0.070, green: 0.078, blue: 0.080)
        case .rose:
            return Color(red: 0.992, green: 0.986, blue: 0.970)
        case .amber:
            return Color(red: 0.965, green: 0.975, blue: 0.935)
        case .porcelainCoralSky:
            return Color(red: 0.941, green: 0.937, blue: 0.957)
        case .matchaCeramic:
            return Color(red: 0.963, green: 0.954, blue: 0.918)
        case .nordicBerry:
            return Color(red: 0.948, green: 0.964, blue: 0.976)
        case .copperBlush, .copperBlushApricot, .copperBlushDeep,
            .oliveBerry, .oliveBerryOlive, .oliveBerryRose, .porcelainCoral,
            .porcelainCoralSand, .vanillaBlue, .cherryCream:
            return background
        case .graphiteMint, .pistachioInk, .mochaLime:
            return Color(red: 0.070, green: 0.078, blue: 0.080)
        }
    }

    var splashLogoColor: Color {
        switch self {
        case .graphiteLime:
            return Color(red: 0.66, green: 0.86, blue: 0.34)
        case .ocean:
            return Color(red: 0.31, green: 0.74, blue: 0.90)
        case .rose:
            return Color(red: 0.90, green: 0.46, blue: 0.18)
        case .amber:
            return Color(red: 0.66, green: 0.86, blue: 0.34)
        case .porcelainCoralSky:
            return Color(red: 0.55, green: 0.66, blue: 0.83)
        case .matchaCeramic:
            return Color(red: 0.42, green: 0.56, blue: 0.32)
        case .nordicBerry:
            return Color(red: 0.58, green: 0.18, blue: 0.38)
        case .copperBlush, .copperBlushApricot, .copperBlushDeep,
            .oliveBerry, .oliveBerryOlive, .oliveBerryRose, .porcelainCoral,
            .porcelainCoralSand, .vanillaBlue, .cherryCream:
            return primary
        case .graphiteMint, .pistachioInk, .mochaLime:
            return primary
        }
    }

    var surface: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.120, green: 0.132, blue: 0.132)
        case .ocean: return Color(red: 0.078, green: 0.118, blue: 0.145)
        case .rose: return Color(red: 1.000, green: 0.996, blue: 0.986)
        case .amber: return Color(red: 0.995, green: 1.000, blue: 0.970)
        case .copperBlush: return Color(red: 1.000, green: 0.968, blue: 0.940)
        case .copperBlushApricot: return Color(red: 1.000, green: 0.948, blue: 0.900)
        case .copperBlushDeep: return Color(red: 1.000, green: 0.970, blue: 0.945)
        case .oliveBerry: return Color(red: 1.000, green: 0.982, blue: 0.968)
        case .oliveBerryOlive: return Color(red: 0.995, green: 0.982, blue: 0.958)
        case .oliveBerryRose: return Color(red: 1.000, green: 0.974, blue: 0.960)
        case .porcelainCoral: return Color(red: 0.985, green: 0.982, blue: 1.000)
        case .porcelainCoralSky: return Color(red: 0.982, green: 0.986, blue: 1.000)
        case .porcelainCoralSand: return Color(red: 1.000, green: 0.972, blue: 0.930)
        case .matchaCeramic: return Color(red: 0.996, green: 0.992, blue: 0.960)
        case .graphiteMint: return Color(red: 0.096, green: 0.112, blue: 0.112)
        case .vanillaBlue: return Color(red: 1.000, green: 0.988, blue: 0.934)
        case .cherryCream: return Color(red: 1.000, green: 0.970, blue: 0.948)
        case .pistachioInk: return Color(red: 0.070, green: 0.125, blue: 0.092)
        case .nordicBerry: return Color(red: 0.982, green: 0.990, blue: 1.000)
        case .mochaLime: return Color(red: 0.145, green: 0.115, blue: 0.090)
        }
    }

    var surfaceMuted: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.155, green: 0.168, blue: 0.162)
        case .ocean: return Color(red: 0.092, green: 0.154, blue: 0.176)
        case .rose: return Color(red: 0.965, green: 0.942, blue: 0.905)
        case .amber: return Color(red: 0.918, green: 0.948, blue: 0.852)
        case .copperBlush: return Color(red: 0.969, green: 0.835, blue: 0.737)
        case .copperBlushApricot: return Color(red: 0.937, green: 0.639, blue: 0.270)
        case .copperBlushDeep: return Color(red: 0.969, green: 0.835, blue: 0.737)
        case .oliveBerry: return Color(red: 0.871, green: 0.827, blue: 0.412)
        case .oliveBerryOlive: return Color(red: 0.871, green: 0.827, blue: 0.412)
        case .oliveBerryRose: return Color(red: 0.945, green: 0.836, blue: 0.812)
        case .porcelainCoral: return Color(red: 0.922, green: 0.788, blue: 0.600)
        case .porcelainCoralSky: return Color(red: 0.863, green: 0.900, blue: 0.956)
        case .porcelainCoralSand: return Color(red: 0.922, green: 0.788, blue: 0.600)
        case .matchaCeramic: return Color(red: 0.860, green: 0.875, blue: 0.780)
        case .graphiteMint: return Color(red: 0.130, green: 0.152, blue: 0.150)
        case .vanillaBlue: return Color(red: 0.890, green: 0.920, blue: 0.960)
        case .cherryCream: return Color(red: 0.965, green: 0.815, blue: 0.835)
        case .pistachioInk: return Color(red: 0.102, green: 0.180, blue: 0.135)
        case .nordicBerry: return Color(red: 0.875, green: 0.910, blue: 0.950)
        case .mochaLime: return Color(red: 0.205, green: 0.165, blue: 0.118)
        }
    }

    var separator: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.78, green: 0.95, blue: 0.48).opacity(0.025)
        case .ocean: return Color(red: 0.45, green: 0.86, blue: 1.00).opacity(0.030)
        case .rose: return Color(red: 0.96, green: 0.45, blue: 0.12).opacity(0.035)
        case .amber: return Color(red: 0.30, green: 0.48, blue: 0.18).opacity(0.035)
        case .copperBlush: return Color(red: 0.70, green: 0.25, blue: 0.04).opacity(0.040)
        case .copperBlushApricot: return Color(red: 0.89, green: 0.43, blue: 0.03).opacity(0.045)
        case .copperBlushDeep: return Color(red: 0.70, green: 0.25, blue: 0.04).opacity(0.052)
        case .oliveBerry: return Color(red: 0.10, green: 0.18, blue: 0.00).opacity(0.055)
        case .oliveBerryOlive: return Color(red: 0.10, green: 0.18, blue: 0.00).opacity(0.050)
        case .oliveBerryRose: return Color(red: 0.88, green: 0.28, blue: 0.36).opacity(0.045)
        case .porcelainCoral: return Color(red: 0.55, green: 0.66, blue: 0.83).opacity(0.055)
        case .porcelainCoralSky: return Color(red: 0.55, green: 0.66, blue: 0.83).opacity(0.050)
        case .porcelainCoralSand: return Color(red: 0.95, green: 0.40, blue: 0.35).opacity(0.045)
        case .matchaCeramic: return Color(red: 0.42, green: 0.56, blue: 0.32).opacity(0.042)
        case .graphiteMint: return Color(red: 0.45, green: 0.86, blue: 0.72).opacity(0.032)
        case .vanillaBlue: return Color(red: 0.40, green: 0.61, blue: 0.82).opacity(0.045)
        case .cherryCream: return Color(red: 0.66, green: 0.08, blue: 0.19).opacity(0.044)
        case .pistachioInk: return Color(red: 0.68, green: 0.82, blue: 0.44).opacity(0.035)
        case .nordicBerry: return Color(red: 0.58, green: 0.18, blue: 0.38).opacity(0.045)
        case .mochaLime: return Color(red: 0.72, green: 0.92, blue: 0.32).opacity(0.034)
        }
    }

    var ink: Color {
        switch preferredColorScheme {
        case .dark: return Tokens.Palette.warmWhite
        case .light: return Color(red: 0.090, green: 0.100, blue: 0.105)
        @unknown default: return Tokens.Palette.warmWhite
        }
    }

    var inkMuted: Color {
        switch preferredColorScheme {
        case .dark: return Tokens.Palette.warmWhite.opacity(0.64)
        case .light: return Color(red: 0.200, green: 0.220, blue: 0.230).opacity(0.66)
        @unknown default: return Tokens.Palette.warmWhite.opacity(0.64)
        }
    }

    var inkSubtle: Color {
        switch preferredColorScheme {
        case .dark: return Tokens.Palette.warmWhite.opacity(0.40)
        case .light: return Color(red: 0.200, green: 0.220, blue: 0.230).opacity(0.40)
        @unknown default: return Tokens.Palette.warmWhite.opacity(0.40)
        }
    }

    var primarySoft: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.66, green: 0.86, blue: 0.34).opacity(0.17)
        case .ocean: return Color(red: 0.31, green: 0.74, blue: 0.90).opacity(0.17)
        case .rose: return Color(red: 0.90, green: 0.46, blue: 0.18).opacity(0.13)
        case .amber: return Color(red: 0.33, green: 0.50, blue: 0.22).opacity(0.12)
        case .copperBlush: return Color(red: 0.70, green: 0.25, blue: 0.04).opacity(0.12)
        case .copperBlushApricot: return Color(red: 0.89, green: 0.43, blue: 0.03).opacity(0.13)
        case .copperBlushDeep: return Color(red: 0.70, green: 0.25, blue: 0.04).opacity(0.15)
        case .oliveBerry: return Color(red: 0.88, green: 0.28, blue: 0.36).opacity(0.12)
        case .oliveBerryOlive: return Color(red: 0.10, green: 0.18, blue: 0.00).opacity(0.11)
        case .oliveBerryRose: return Color(red: 0.88, green: 0.28, blue: 0.36).opacity(0.12)
        case .porcelainCoral: return Color(red: 0.55, green: 0.66, blue: 0.83).opacity(0.16)
        case .porcelainCoralSky: return Color(red: 0.55, green: 0.66, blue: 0.83).opacity(0.16)
        case .porcelainCoralSand: return Color(red: 0.92, green: 0.79, blue: 0.60).opacity(0.18)
        case .matchaCeramic: return Color(red: 0.42, green: 0.56, blue: 0.32).opacity(0.13)
        case .graphiteMint: return Color(red: 0.45, green: 0.86, blue: 0.72).opacity(0.18)
        case .vanillaBlue: return Color(red: 0.40, green: 0.61, blue: 0.82).opacity(0.14)
        case .cherryCream: return Color(red: 0.66, green: 0.08, blue: 0.19).opacity(0.12)
        case .pistachioInk: return Color(red: 0.68, green: 0.82, blue: 0.44).opacity(0.18)
        case .nordicBerry: return Color(red: 0.58, green: 0.18, blue: 0.38).opacity(0.12)
        case .mochaLime: return Color(red: 0.72, green: 0.92, blue: 0.32).opacity(0.18)
        }
    }

    var accent: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.48, green: 0.60, blue: 0.42)
        case .ocean: return Color(red: 0.42, green: 0.82, blue: 0.74)
        case .rose: return Color(red: 0.96, green: 0.64, blue: 0.30)
        case .amber: return Color(red: 0.66, green: 0.80, blue: 0.28)
        case .copperBlush: return Color(red: 0.89, green: 0.43, blue: 0.03)
        case .copperBlushApricot: return Color(red: 0.70, green: 0.25, blue: 0.04)
        case .copperBlushDeep: return Color(red: 0.94, green: 0.64, blue: 0.27)
        case .oliveBerry: return Color(red: 0.87, green: 0.83, blue: 0.41)
        case .oliveBerryOlive: return Color(red: 0.88, green: 0.28, blue: 0.36)
        case .oliveBerryRose: return Color(red: 0.871, green: 0.827, blue: 0.412)
        case .porcelainCoral: return Color(red: 0.55, green: 0.66, blue: 0.83)
        case .porcelainCoralSky: return Color(red: 0.95, green: 0.40, blue: 0.35)
        case .porcelainCoralSand: return Color(red: 0.55, green: 0.66, blue: 0.83)
        case .matchaCeramic: return Color(red: 0.84, green: 0.78, blue: 0.34)
        case .graphiteMint: return Color(red: 0.35, green: 0.70, blue: 0.92)
        case .vanillaBlue: return Color(red: 0.94, green: 0.44, blue: 0.36)
        case .cherryCream: return Color(red: 0.94, green: 0.48, blue: 0.36)
        case .pistachioInk: return Color(red: 0.40, green: 0.62, blue: 0.42)
        case .nordicBerry: return Color(red: 0.40, green: 0.58, blue: 0.78)
        case .mochaLime: return Color(red: 0.72, green: 0.48, blue: 0.25)
        }
    }

    var accentSoft: Color { accent.opacity(0.18) }

    var muted: Color {
        switch self {
        case .graphiteLime: return Color(red: 0.50, green: 0.65, blue: 0.42)
        case .ocean: return Color(red: 0.34, green: 0.63, blue: 0.76)
        case .rose: return Color(red: 0.78, green: 0.42, blue: 0.18)
        case .amber: return Color(red: 0.46, green: 0.58, blue: 0.26)
        case .copperBlush: return Color(red: 0.94, green: 0.64, blue: 0.27)
        case .copperBlushApricot: return Color(red: 0.97, green: 0.835, blue: 0.737)
        case .copperBlushDeep: return Color(red: 0.89, green: 0.43, blue: 0.03)
        case .oliveBerry: return Color(red: 0.10, green: 0.18, blue: 0.00)
        case .oliveBerryOlive: return Color(red: 0.871, green: 0.827, blue: 0.412)
        case .oliveBerryRose: return Color(red: 0.10, green: 0.18, blue: 0.00)
        case .porcelainCoral: return Color(red: 0.92, green: 0.79, blue: 0.60)
        case .porcelainCoralSky: return Color(red: 0.92, green: 0.79, blue: 0.60)
        case .porcelainCoralSand: return Color(red: 0.95, green: 0.40, blue: 0.35)
        case .matchaCeramic: return Color(red: 0.56, green: 0.64, blue: 0.45)
        case .graphiteMint: return Color(red: 0.32, green: 0.58, blue: 0.55)
        case .vanillaBlue: return Color(red: 0.86, green: 0.73, blue: 0.48)
        case .cherryCream: return Color(red: 0.82, green: 0.36, blue: 0.42)
        case .pistachioInk: return Color(red: 0.50, green: 0.70, blue: 0.40)
        case .nordicBerry: return Color(red: 0.52, green: 0.64, blue: 0.76)
        case .mochaLime: return Color(red: 0.52, green: 0.36, blue: 0.22)
        }
    }

    var onPrimary: Color {
        switch self {
        case .graphiteLime, .ocean: return Tokens.Palette.graphite
        case .graphiteMint, .pistachioInk, .mochaLime: return Tokens.Palette.graphite
        case .rose, .amber, .copperBlush, .copperBlushApricot, .copperBlushDeep,
            .oliveBerry, .oliveBerryOlive, .oliveBerryRose, .porcelainCoral,
            .porcelainCoralSky, .porcelainCoralSand, .matchaCeramic, .vanillaBlue,
            .cherryCream, .nordicBerry:
            return Tokens.Palette.warmWhite
        }
    }
}
