import SwiftUI

/// Step that captures the user's display name. Surfaces right after
/// Welcome so Coach Ola can greet them by name on every subsequent step.
/// No email here: the user has already signed in (Apple / Google / email),
/// so the account email comes from the auth provider and must not be
/// overwritten by a second, possibly different, typed address.
struct AccountStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @FocusState private var focused: Field?

    private enum Field {
        case displayName
    }

    private var canProceed: Bool {
        !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "What's your name?",
            subtitle: "That's how Ola will address you.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            primaryEnabled: canProceed,
            onPrimary: onContinue,
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    MonoField(label: L("Name")) {
                        TextField(L("Anna"), text: $profile.displayName)
                            .focused($focused, equals: .displayName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                            .onSubmit { if canProceed { onContinue() } }
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
}
