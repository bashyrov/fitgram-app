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
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(Tokens.Palette.primary)
            )
            .mealgramShadow(Tokens.Shadow.card)
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
            .opacity(effectiveEnabled ? 1 : 0.55)
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
