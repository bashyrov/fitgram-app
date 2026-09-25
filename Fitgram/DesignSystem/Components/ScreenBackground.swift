import SwiftUI

/// Clean theme-aware canvas shared by full-screen surfaces.
struct ScreenBackground: View {
    enum Mood {
        case calm
        case coach
        case social
        case progress
        case warm
    }

    var mood: Mood = .calm
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private var palette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    var body: some View {
        palette.background
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}
