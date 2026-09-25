import SwiftUI

/// User-controlled colour scheme preference. Backed by AppStorage so the
/// choice survives app launch and is read at the root view's
/// `.preferredColorScheme` binding.
enum ThemePreference: String, CaseIterable, Identifiable {
    case auto
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .auto: return L("Auto")
        case .light: return L("Jasny")
        case .dark: return L("Ciemny")
        }
    }
}
