import SwiftUI

/// Email + password sign-in with an inline "create account" mode. There is
/// no inbox step: the project doesn't require email confirmation, so both
/// modes land the user signed in.
struct EmailSignInSheet: View {
    let authService: AuthService
    let onDismiss: () -> Void

    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    enum Mode: Hashable {
        case signIn
        case createAccount
    }

    private enum Field {
        case email
        case password
    }

    private var canSubmit: Bool {
        !isSubmitting && !email.trimmingCharacters(in: .whitespaces).isEmpty
            && password.count >= EmailAuthProvider.minimumPasswordLength
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                form
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.bottom, Tokens.Space.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom, spacing: 0) {
                MonoBottomBar {
                    submitButton
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij")) {
                        onDismiss()
                    }
                    .accessibilityLabel(Text(L("Close")))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focusedField = .email }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoH1(
                text: mode == .signIn ? L("Zaloguj się e-mailem") : L("Załóż konto"),
                sub: mode == .signIn
                    ? L("Wpisz e-mail i hasło do swojego konta Fitgram.")
                    : L("Wystarczy e-mail i hasło. Bez potwierdzania skrzynki.")
            )

            MonoSegmented(
                selection: $mode,
                options: [
                    (value: Mode.signIn, title: L("Logowanie")),
                    (value: Mode.createAccount, title: L("Nowe konto")),
                ]
            )
            .padding(.top, 16)
            .onChange(of: mode) { _, _ in errorMessage = nil }

            VStack(alignment: .leading, spacing: 12) {
                MonoField(label: L("Adres e-mail")) {
                    TextField("ty@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .password }
                        .accessibilityIdentifier(A11yID.Auth.emailField)
                }

                MonoField(label: L("Hasło")) {
                    HStack(spacing: 8) {
                        Group {
                            if isPasswordVisible {
                                TextField(L("Hasło"), text: $password)
                            } else {
                                SecureField(L("Hasło"), text: $password)
                            }
                        }
                        .textContentType(mode == .signIn ? .password : .newPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                        .accessibilityIdentifier(A11yID.Auth.passwordField)
                        Button {
                            isPasswordVisible.toggle()
                        } label: {
                            Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Tokens.Mono.muted)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(isPasswordVisible ? L("Ukryj hasło") : L("Pokaż hasło")))
                    }
                }

                if mode == .createAccount {
                    Text(L("Hasło musi mieć co najmniej 6 znaków."))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier(A11yID.Auth.emailError)
                }
            }
            .monoCard(padding: 16)
            .padding(.top, 12)
        }
    }

    private var submitButton: some View {
        Button(action: submit) {
            HStack(spacing: 8) {
                if isSubmitting {
                    ProgressView()
                        .tint(Tokens.Mono.onHero)
                }
                Text(mode == .signIn ? L("Zaloguj się") : L("Załóż konto"))
            }
        }
        .buttonStyle(MonoButtonStyle(kind: .dark))
        .disabled(!canSubmit)
        .accessibilityIdentifier(A11yID.Auth.emailSubmit)
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true
        focusedField = nil
        Task {
            defer { isSubmitting = false }
            do {
                try await authService.signInWithEmail(
                    email: email, password: password, createAccount: mode == .createAccount)
                onDismiss()
            } catch {
                errorMessage = error.localizedDescription
                if (error as? EmailAuthError) == .accountExists {
                    mode = .signIn
                }
            }
        }
    }
}
