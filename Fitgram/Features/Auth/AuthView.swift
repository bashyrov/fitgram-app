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

            VStack(spacing: 0) {
                header
                    .padding(.top, 40)
                Spacer(minLength: 20)
                VStack(spacing: 8) {
                    buttonStack
                    footer
                }
                .padding(.top, 20)
                .padding(.bottom, Tokens.Space.lg)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
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

    /// Dark hero: Fitgram mark, display wordmark and the tagline.
    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            FitgramLogoMark(color: Tokens.Mono.hi)
                .frame(width: 120, height: 56)

            Text(verbatim: "Fitgram")
                .font(Tokens.Font.monoDisplay(44))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("Twój spokojny tracker kalorii.")
                .font(Tokens.Font.manrope(16, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
        .accessibilityElement(children: .combine)
    }

    private var buttonStack: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.continue) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { _ in
                // We route through `AuthService` so the same code path is used
                // everywhere — the button's onCompletion fires after our
                // provider's continuation already resolved, so it's a no-op.
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(Capsule())
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
                systemImage: "globe"
            ) {
                Task { await authService.signIn(with: .google) }
            }
            .accessibilityIdentifier(A11yID.Auth.googleButton)

            SocialAuthButton(
                title: "Kontynuuj e-mailem",
                systemImage: "envelope"
            ) {
                isEmailSheetPresented = true
            }
            .accessibilityIdentifier(A11yID.Auth.emailButton)
        }
        .disabled(session.isWorking)
        .opacity(session.isWorking ? 0.6 : 1)
    }

    /// One centred paragraph like the mockup: muted policy line with bold inline links.
    private var footer: some View {
        Text(footerText)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .tint(Tokens.Palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
    }

    private var footerText: AttributedString {
        var text = AttributedString(
            TL(
                pl: "Rejestrując się, akceptujesz nasze zasady.",
                en: "By signing up, you accept our policies.",
                uk: "Реєструючись, ти приймаєш наші правила.",
                ru: "Регистрируясь, ты принимаешь наши правила.",
                es: "Al registrarte, aceptas nuestras políticas."
            ) + " "
        )
        text.append(
            footerLink(
                TL(pl: "Warunki", en: "Terms", uk: "Умови", ru: "Условия", es: "Términos"),
                url: termsURL
            )
        )
        text.append(AttributedString(" · "))
        text.append(
            footerLink(
                TL(pl: "Prywatność", en: "Privacy", uk: "Приватність", ru: "Конфиденциальность", es: "Privacidad"),
                url: privacyURL
            )
        )
        return text
    }

    private func footerLink(_ title: String, url: URL?) -> AttributedString {
        var link = AttributedString(title)
        link.link = url
        link.swiftUI.font = Tokens.Font.manrope(12, weight: 800)
        link.swiftUI.foregroundColor = Tokens.Palette.ink
        return link
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
                    .fill(Tokens.Mono.track)
            )
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.top, Tokens.Space.lg)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { session.clearError() }
            .accessibilityIdentifier(A11yID.Auth.errorBanner)
        }
    }
}
