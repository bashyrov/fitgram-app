import SwiftUI

/// Step that captures the user's display name + optional email. Surfaces
/// right after Welcome so Coach Ola can greet them by name on every
/// subsequent step. Both fields are optional from a hard-blocker point
/// of view — empty values just don't overwrite whatever the auth
/// provider already supplied.
struct AccountStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @FocusState private var focused: Field?

    private enum Field {
        case displayName
        case email
    }

    private var canProceed: Bool {
        !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "What's your name?",
            subtitle: "That's how Ola will address you. Email is optional — only used for reminders.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            primaryEnabled: canProceed,
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.lg) {
                    fieldCard(
                        label: "Name",
                        placeholder: "Anna",
                        text: $profile.displayName,
                        focusField: .displayName,
                        contentType: .givenName,
                        capitalization: .words
                    )
                    fieldCard(
                        label: "Adres e-mail",
                        placeholder: "ty@example.com",
                        text: $profile.emailAddress,
                        focusField: .email,
                        contentType: .emailAddress,
                        capitalization: .never,
                        keyboard: .emailAddress
                    )
                    Text("You can change this later in Profile.")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        )
        .onAppear { focused = .displayName }
    }

    @ViewBuilder
    private func fieldCard(
        label: LocalizedStringKey,
        placeholder: LocalizedStringKey,
        text: Binding<String>,
        focusField: Field,
        contentType: UITextContentType,
        capitalization: TextInputAutocapitalization,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xs) {
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .textCase(.uppercase)
            TextField(placeholder, text: text)
                .focused($focused, equals: focusField)
                .textContentType(contentType)
                .textInputAutocapitalization(capitalization)
                .keyboardType(keyboard)
                .autocorrectionDisabled(focusField == .email)
                .padding(.vertical, Tokens.Space.md)
                .padding(.horizontal, Tokens.Space.lg)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .fill(.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .stroke(
                            focused == focusField
                                ? Tokens.Palette.primary
                                : Tokens.Palette.inkSubtle.opacity(0.25),
                            lineWidth: focused == focusField ? 2 : 1
                        )
                )
        }
    }
}
