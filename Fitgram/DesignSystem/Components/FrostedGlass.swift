import SwiftUI

struct FrostedGlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 22
    var fillOpacity: Double = 0.66
    var borderOpacity: Double = 0.06
    var glowOpacity: Double = 0.055
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private var palette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    func body(content: Content) -> some View {
        // Design D ("Graphite Mono"): flat surface + hairline, no glass or glow.
        // The signature is kept so every existing call site picks up the new look.
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(palette.mono.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func frostedGlass(
        cornerRadius: CGFloat = 22,
        fillOpacity: Double = 0.66,
        borderOpacity: Double = 0.06,
        glowOpacity: Double = 0.055
    ) -> some View {
        modifier(
            FrostedGlassModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                borderOpacity: borderOpacity,
                glowOpacity: glowOpacity
            )
        )
    }
}
