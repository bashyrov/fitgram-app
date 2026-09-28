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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    form
                        .padding(.horizontal, Tokens.Space.screenPadding)
                        .padding(.top, Tokens.Space.xl)
                }
                .scrollDismissesKeyboard(.interactively)
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
                    .accessibilityLabel(Text(L("Close")))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { focusedField = .email }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(mode == .signIn ? L("Zaloguj się e-mailem") : L("Załóż konto"))
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    mode == .signIn
                        ? L("Wpisz e-mail i hasło do swojego konta Fitgram.")
                        : L("Wystarczy e-mail i hasło. Bez potwierdzania skrzynki.")
                )
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            }

            Picker("", selection: $mode) {
                Text(L("Logowanie")).tag(Mode.signIn)
                Text(L("Nowe konto")).tag(Mode.createAccount)
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in errorMessage = nil }

            fieldLabel(L("Adres e-mail"))
            TextField("ty@example.com", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }
                .modifier(AuthFieldStyle())
                .accessibilityIdentifier(A11yID.Auth.emailField)

            fieldLabel(L("Hasło"))
            HStack {
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
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
                .accessibilityLabel(Text(isPasswordVisible ? L("Ukryj hasło") : L("Pokaż hasło")))
            }
            .modifier(AuthFieldStyle())
            if mode == .createAccount {
                Text(L("Hasło musi mieć co najmniej 6 znaków."))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.error)
                    .accessibilityIdentifier(A11yID.Auth.emailError)
            }

            Button(action: submit) {
                HStack {
                    if isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(mode == .signIn ? L("Zaloguj się") : L("Załóż konto"))
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
            .disabled(!canSubmit)
            .opacity(canSubmit ? 1 : 0.6)
            .accessibilityIdentifier(A11yID.Auth.emailSubmit)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.inkMuted)
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

private struct AuthFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.vertical, Tokens.Space.md)
            .padding(.horizontal, Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Palette.inkSubtle.opacity(0.2), lineWidth: 1)
            )
    }
}
