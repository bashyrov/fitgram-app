import SwiftUI

/// Shared layout for each onboarding step. Keeps spacing + button placement
/// consistent so steps just provide content and a CTA title.
struct OnboardingStepScaffold<Content: View>: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    let primaryTitle: LocalizedStringKey
    var primarySystemImage: String?
    var primaryEnabled: Bool = true
    var secondaryTitle: LocalizedStringKey?
    var secondaryAction: (() -> Void)?
    let onPrimary: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(title)
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: Tokens.Space.lg)
            VStack(spacing: Tokens.Space.sm) {
                PrimaryButton(
                    title: primaryTitle,
                    systemImage: primarySystemImage,
                    isEnabled: primaryEnabled,
                    action: onPrimary
                )
                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                            .font(Tokens.Font.callout)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    .padding(.bottom, Tokens.Space.xs)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Palette.background)
    }
}
