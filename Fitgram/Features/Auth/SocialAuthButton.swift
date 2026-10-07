import SwiftUI

/// Design D outline capsule auth button used for Google + e-mail. Sign in
/// with Apple uses Apple's own `SignInWithAppleButton` (we don't restyle it
/// — the guidelines require the system control).
struct SocialAuthButton: View {
    let title: LocalizedStringKey
    let systemImage: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(MonoButtonStyle(kind: .outline, height: 54))
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
