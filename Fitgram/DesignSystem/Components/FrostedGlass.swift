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
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(palette.surface.opacity(fillOpacity * 0.82))
            }
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.surface.opacity(fillOpacity * 0.95),
                                palette.surfaceMuted.opacity(fillOpacity * 0.72),
                                palette.primary.opacity(fillOpacity * 0.08),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.warmWhite.opacity(glowOpacity),
                                .clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .center
                        )
                    )
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
