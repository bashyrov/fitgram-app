import SwiftUI

/// Pill-shaped, neutral-surface auth button used for Google + e-mail. Sign in
/// with Apple uses Apple's own `SignInWithAppleButton` (we don't restyle it
/// — the guidelines require the system control).
struct SocialAuthButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 22, alignment: .center)
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
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview("Social buttons") {
    VStack(spacing: Tokens.Space.md) {
        SocialAuthButton(title: "Kontynuuj z Google", systemImage: "g.circle.fill", action: {})
        SocialAuthButton(title: "Kontynuuj e-mailem", systemImage: "envelope.fill", action: {})
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
