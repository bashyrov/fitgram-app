import SwiftUI

/// Pill-shaped, sage-filled call-to-action. Reach for this for the single most
/// important action on a screen.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var environmentEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Mono.onHero)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(Tokens.Font.manrope(16, weight: 800))
            }
            .foregroundStyle(Tokens.Mono.onHero)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                Capsule(style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
            .opacity(effectiveEnabled ? 1 : 0.5)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!effectiveEnabled || isLoading)
        .accessibilityAddTraits(.isButton)
    }

    private var effectiveEnabled: Bool { isEnabled && environmentEnabled }
}

#Preview("Primary") {
    VStack(spacing: Tokens.Space.lg) {
        PrimaryButton(title: "Zacznij", systemImage: "sparkles") {}
        PrimaryButton(title: "Ładowanie", isLoading: true) {}
        PrimaryButton(title: "Wyłączony", isEnabled: false) {}
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
