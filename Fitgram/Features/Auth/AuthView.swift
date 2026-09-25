import AuthenticationServices
import SwiftUI

/// Entry point for unauthenticated users. Three options in the order Apple
/// requires (Apple first), all built on the same pill-shape so the screen
/// reads calmly.
struct AuthView: View {
    @Environment(AuthSession.self) private var session
    let authService: AuthService

    @State private var errorBannerVisible = false
    @State private var isEmailSheetPresented = false

    var body: some View {
        ZStack {
            Tokens.Palette.background
                .ignoresSafeArea()

            VStack(spacing: Tokens.Space.xxl) {
                Spacer()
                header
                Spacer()
                buttonStack
                footer
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.xl)
        }
        .overlay(alignment: .top) { errorBanner }
        .animation(Tokens.Motion.gentle, value: session.lastError)
        .onChange(of: session.lastError) { _, newValue in
            errorBannerVisible = newValue != nil
        }
        .sheet(isPresented: $isEmailSheetPresented) {
            EmailSignInSheet(authService: authService) {
                isEmailSheetPresented = false
            }
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Tokens.Space.md) {
            Image("FitgramLogoCitrus")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 172, height: 112)
            .fitgramShadow(Tokens.Shadow.float)

            Text("Fitgram")
                .font(Tokens.Font.display)
                .foregroundStyle(Tokens.Palette.ink)

            Text("Twój spokojny tracker kalorii.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
        }
    }

    private var buttonStack: some View {
        VStack(spacing: Tokens.Space.md) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in
                // We route through `AuthService` so the same code path is used
                // everywhere — the button's onCompletion fires after our
                // provider's continuation already resolved, so it's a no-op.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 56)
            .clipShape(.rect(cornerRadius: Tokens.Radius.pill, style: .continuous))
            .overlay(
                Button {
                    Task { await authService.signIn(with: .apple) }
                } label: {
                    Color.clear
                }
                .accessibilityLabel(Text("Kontynuuj z Apple"))
            )

            SocialAuthButton(
                title: "Kontynuuj z Google",
                systemImage: "g.circle.fill"
            ) {
                Task { await authService.signIn(with: .google) }
            }
            .accessibilityIdentifier(A11yID.Auth.googleButton)

            SocialAuthButton(
                title: "Kontynuuj e-mailem",
                systemImage: "envelope.fill"
            ) {
                isEmailSheetPresented = true
            }
            .accessibilityIdentifier(A11yID.Auth.emailButton)
        }
        .disabled(session.isWorking)
        .opacity(session.isWorking ? 0.6 : 1)
    }

    private var footer: some View {
        VStack(spacing: Tokens.Space.sm) {
            Text(
                TL(
                    pl: "Rejestrując się, akceptujesz nasze zasady.",
                    en: "By signing up, you accept our policies.",
                    uk: "Реєструючись, ти приймаєш наші правила.",
                    ru: "Регистрируясь, ты принимаешь наши правила.",
                    es: "Al registrarte, aceptas nuestras políticas."
                )
            )
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
                .multilineTextAlignment(.center)

            HStack(spacing: Tokens.Space.md) {
                if let termsURL {
                    Link(
                        TL(
                            pl: "Warunki",
                            en: "Terms",
                            uk: "Умови",
                            ru: "Условия",
                            es: "Términos"
                        ),
                        destination: termsURL
                    )
                }
                if let privacyURL {
                    Link(
                        TL(
                            pl: "Prywatność",
                            en: "Privacy",
                            uk: "Приватність",
                            ru: "Конфиденциальность",
                            es: "Privacidad"
                        ),
                        destination: privacyURL
                    )
                }
            }
            .font(Tokens.Font.caption.weight(.semibold))
            .foregroundStyle(Tokens.Palette.primary)
        }
        .padding(.top, Tokens.Space.sm)
    }

    private var termsURL: URL? {
        URL(string: "https://fitgram.space/terms")
    }

    private var privacyURL: URL? {
        URL(string: "https://fitgram.space/privacy")
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = session.lastError, errorBannerVisible {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Tokens.Palette.accent)
                Text(error.userMessage)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
            }
            .padding(.horizontal, Tokens.Space.lg)
            .padding(.vertical, Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.accentSoft)
            )
            .fitgramShadow(Tokens.Shadow.card)
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.lg)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { session.clearError() }
            .accessibilityIdentifier(A11yID.Auth.errorBanner)
        }
    }
}
