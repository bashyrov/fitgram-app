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

        var contentType: UITextContentType {
            switch self {
            case .displayName: .givenName
            case .email: .emailAddress
            }
        }

        var capitalization: TextInputAutocapitalization {
            switch self {
            case .displayName: .words
            case .email: .never
            }
        }

        var keyboard: UIKeyboardType {
            switch self {
            case .displayName: .default
            case .email: .emailAddress
            }
        }
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
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 12) {
                        field(
                            label: L("Name"),
                            placeholder: "Anna",
                            text: $profile.displayName,
                            focusField: .displayName
                        )
                        field(
                            label: L("Adres e-mail"),
                            placeholder: "ty@example.com",
                            text: $profile.emailAddress,
                            focusField: .email
                        )
                    }
                    .monoCard(padding: 16)

                    Text("You can change this later in Profile.")
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                }
            }
        )
        .onAppear { focused = .displayName }
    }

    private func field(
        label: String,
        placeholder: String,
        text: Binding<String>,
        focusField: Field
    ) -> some View {
        MonoField(label: label) {
            // String (not LocalizedStringKey) placeholder so the sample
            // address isn't auto-linked as Markdown.
            TextField(L(placeholder), text: text)
                .focused($focused, equals: focusField)
                .textContentType(focusField.contentType)
                .textInputAutocapitalization(focusField.capitalization)
                .keyboardType(focusField.keyboard)
                .autocorrectionDisabled(focusField == .email)
        }
    }
}
