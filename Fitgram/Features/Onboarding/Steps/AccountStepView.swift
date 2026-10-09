import SwiftUI

/// Step that captures the user's display name and their one-time username.
/// Surfaces right after Welcome so Coach Ola can greet them by name on
/// every subsequent step. No email here: the user has already signed in
/// (Apple / Google / email), so the account email comes from the auth
/// provider and must not be overwritten by a second, possibly different,
/// typed address.
struct AccountStepView: View {
    @Binding var profile: OnboardingProfile
    let userID: String
    let onContinue: () -> Void

    @FocusState private var focused: Field?
    @State private var usernameStatus: UsernameField.Status = .idle
    @State private var lockedUsername: String?
    @State private var isClaiming = false
    @State private var socialProfile: any SocialProfileServing = SocialProfileServiceFactory.make()

    private enum Field {
        case displayName
    }

    private var canProceed: Bool {
        !profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && usernameStatus.isReady && !isClaiming
    }

    var body: some View {
        OnboardingStepScaffold(
            title: "What's your name?",
            subtitle: "That's how Ola will address you.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            primaryEnabled: canProceed,
            onPrimary: { Task { await claimAndContinue() } },
            content: {
                VStack(alignment: .leading, spacing: 10) {
                    MonoField(label: L("Name")) {
                        TextField(L("Anna"), text: $profile.displayName)
                            .focused($focused, equals: .displayName)
                            .textContentType(.givenName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.next)
                    }
                    .monoCard(padding: 16)

                    Text("You can change this later in Profile.")
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)

                    UsernameField(
                        username: $profile.username,
                        status: $usernameStatus,
                        socialProfile: socialProfile,
                        lockedUsername: lockedUsername
                    )
                    .monoCard(padding: 16)
                    .padding(.top, 6)
                    .accessibilityIdentifier(A11yID.Onboarding.usernameField)
                }
            }
        )
        .onAppear {
            focused = .displayName
            if profile.username.isEmpty {
                profile.username = UsernamePolicy.suggestion(from: profile.displayName)
            }
        }
        .task { await loadExisting() }
        .onChange(of: profile.displayName) { _, name in
            // Suggest a username from the name while the field is empty.
            guard lockedUsername == nil, profile.username.isEmpty else { return }
            profile.username = UsernamePolicy.suggestion(from: name)
        }
    }

    /// An account that already picked a username (e.g. on another phone)
    /// keeps it — the field shows it read-only.
    private func loadExisting() async {
        if profile.username.isEmpty {
            profile.username = UsernamePolicy.suggestion(from: profile.displayName)
        }
        if let existing = try? await socialProfile.chosenUsername(userID: userID) {
            profile.username = existing
            lockedUsername = existing
        }
    }

    private func claimAndContinue() async {
        guard canProceed else { return }
        if usernameStatus == .locked {
            onContinue()
            return
        }
        isClaiming = true
        defer { isClaiming = false }
        do {
            try await socialProfile.claimUsername(profile.username, displayName: profile.displayName, userID: userID)
            onContinue()
        } catch UsernameClaimError.taken {
            usernameStatus = .taken
        } catch UsernameClaimError.invalid {
            usernameStatus = .invalid(UsernamePolicy.problem(for: profile.username)?.message ?? "")
        } catch {
            // Offline: keep the choice locally; Znajomi claims it later.
            onContinue()
        }
    }
}
