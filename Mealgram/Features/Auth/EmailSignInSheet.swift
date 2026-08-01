import SwiftUI

/// Two-state sheet: email entry → "check your inbox" once Supabase
/// confirms the magic link was sent. Closing the sheet doesn't cancel the
/// flow — `AuthService.completeEmailSignIn` still fires when the user taps
/// the link in their email.
struct EmailSignInSheet: View {
    let authService: AuthService
    let onDismiss: () -> Void

    @State private var email: String = ""
    @State private var phase: Phase = .input
    @State private var errorMessage: String?
    @FocusState private var isEmailFocused: Bool

    enum Phase {
        case input
        case sending
        case sent
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                content
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.xl)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                            .font(.title3)
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if phase == .input {
                    isEmailFocused = true
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .input, .sending:
            inputState
        case .sent:
            sentState
        }
    }

    private var inputState: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.xl) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Zaloguj się przez e-mail")
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Wyślemy Ci link do logowania. Bez haseł, bez tarapatów.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }

            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Adres e-mail")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                TextField("ty@example.com", text: $email)
                    .textFieldStyle(.plain)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.vertical, Tokens.Space.md)
                    .padding(.horizontal, Tokens.Space.lg)
                    .background(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .fill(.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .stroke(Tokens.Palette.inkSubtle.opacity(0.2), lineWidth: 1)
                    )
                    .focused($isEmailFocused)
                    .submitLabel(.go)
                    .onSubmit { submit() }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.accent)
            }

            Button {
                submit()
            } label: {
                HStack {
                    if phase == .sending {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                    Text(phase == .sending ? "Wysyłanie…" : "Wyślij link")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.pill, style: .continuous)
                        .fill(Tokens.Palette.primary)
                )
            }
            .disabled(phase == .sending || email.isEmpty)
            .opacity(phase == .sending || email.isEmpty ? 0.7 : 1)

            Spacer()
        }
    }

    private var sentState: some View {
        VStack(alignment: .center, spacing: Tokens.Space.xl) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 140, height: 140)
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            VStack(spacing: Tokens.Space.md) {
                Text("Sprawdź skrzynkę")
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Wysłaliśmy link do logowania na \(email). Tapnij go z telefonu, na którym masz Mealgrama, żeby się zalogować."
                )
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
            }
            Spacer()
            Button {
                phase = .input
                isEmailFocused = true
            } label: {
                Text("Zmień adres e-mail")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .padding(.bottom, Tokens.Space.xl)
        }
    }

    private func submit() {
        errorMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        phase = .sending
        Task {
            do {
                try await authService.requestEmailMagicLink(email: trimmed)
                phase = .sent
            } catch {
                phase = .input
                errorMessage = error.localizedDescription
            }
        }
    }
}
