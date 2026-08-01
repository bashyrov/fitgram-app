import SwiftUI

/// Shared layout for each onboarding step. Keeps spacing + button placement
/// consistent so steps just provide content and a CTA title.
///
/// Content is hosted in a ScrollView so tall steps (Profile picker with
/// 3 sections of cards + 2 text fields) don't get cut off, and the
/// keyboard inset is automatically respected.
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
        VStack(spacing: 0) {
            ScrollView {
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
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.lg)
                // Generous bottom padding so the last content row never
                // hides under the floating CTA + its fade gradient.
                .padding(.bottom, 160)
            }
            .scrollDismissesKeyboard(.interactively)

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
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.md)
            .padding(.bottom, Tokens.Space.xl)
            .background(
                LinearGradient(
                    colors: [Tokens.Palette.background.opacity(0), Tokens.Palette.background],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: 32)
                .frame(maxHeight: .infinity, alignment: .top)
                .offset(y: -32)
                .allowsHitTesting(false)
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Palette.background)
    }
}
