import SwiftUI

/// Shared layout for each onboarding step. Keeps spacing + button placement
/// consistent so steps just provide content and a CTA title.
///
/// Content is hosted in a ScrollView so tall steps (Profile picker with
/// 3 sections of cards + 2 text fields) don't get cut off, and the
/// keyboard inset is automatically respected.
struct OnboardingStepScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    let primaryTitle: LocalizedStringKey
    var primarySystemImage: String?
    var primaryEnabled: Bool = true
    var secondaryTitle: LocalizedStringKey?
    var secondaryAction: (() -> Void)?
    let onPrimary: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // `MonoH1` takes a String: route the catalog keys through
                // L(); already-localized strings (TL) fall through unchanged.
                MonoH1(text: L(title), sub: subtitle.map { L($0) })
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Palette.background)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MonoBottomBar {
                Button(action: onPrimary) {
                    // Design D CTAs are text-only; `primarySystemImage` is kept
                    // for API compatibility with the step views.
                    Text(primaryTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(MonoButtonStyle(kind: .dark))
                .disabled(!primaryEnabled)

                if let secondaryTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryTitle)
                    }
                    .buttonStyle(MonoButtonStyle(kind: .ghost, height: 44))
                }
            }
        }
    }
}
