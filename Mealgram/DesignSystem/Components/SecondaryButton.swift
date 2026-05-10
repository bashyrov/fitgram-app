import SwiftUI

/// Outlined pill button — same shape as `PrimaryButton`, no fill.
struct SecondaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let action: () -> Void

    @Environment(\.isEnabled) private var environmentEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                }
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
            }
            .foregroundStyle(Tokens.Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                    .stroke(Tokens.Palette.separator, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous))
            .opacity(environmentEnabled ? 1 : 0.55)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Secondary") {
    VStack(spacing: Tokens.Space.lg) {
        SecondaryButton(title: "Pomiń", systemImage: "arrow.right") {}
        SecondaryButton(title: "Anuluj") {}
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
