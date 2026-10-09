import AuthenticationServices
import SwiftUI

/// Entry point for unauthenticated users: the full-width FIT/GRAM lockup
/// over the FITGRAM stripes (same as the first onboarding screen), then
/// the three sign-in options with Apple first, as Apple requires.
struct AuthView: View {
    @Environment(AuthSession.self) private var session
    let authService: AuthService

    @State private var errorBannerVisible = false
    @State private var isEmailSheetPresented = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            WordmarkStripes()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 16)
                header
                Spacer(minLength: 20)
                VStack(spacing: 8) {
                    buttonStack
                    footer
                }
                .padding(.bottom, Tokens.Space.sm)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
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

    /// Full-width FIT / GRAM lockup and the tagline.
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            FitgramWordmarkLockup(appeared: appeared)
            Text(
                TL(
                    pl: "Jedno zdjęcie — i wiesz, co zjadłeś. Zacznij za darmo.",
                    en: "One photo and you know what you ate. Start for free.",
                    uk: "Одне фото — і ти знаєш, що з'їв. Почни безкоштовно.",
                    ru: "Одно фото — и ты знаешь, что съел. Начни бесплатно.",
                    es: "Una foto y sabes lo que comiste. Empieza gratis.")
            )
            .font(Tokens.Font.manrope(24, weight: 800))
            .foregroundStyle(Tokens.Mono.Brand.muted)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .opacity(appeared ? 1 : 0)
        }
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
            .signInWithAppleButtonStyle(Tokens.Mono.Brand.isLight ? .black : .white)
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
                systemImage: "globe",
                kind: Tokens.Mono.Brand.isLight ? .outline : .heroOutline
            ) {
                Task { await authService.signIn(with: .google) }
            }
            .background(Capsule().fill(Tokens.Mono.Brand.background))
            .accessibilityIdentifier(A11yID.Auth.googleButton)

            SocialAuthButton(
                title: "Kontynuuj e-mailem",
                systemImage: "envelope",
                kind: Tokens.Mono.Brand.isLight ? .outline : .heroOutline
            ) {
                isEmailSheetPresented = true
            }
            .background(Capsule().fill(Tokens.Mono.Brand.background))
            .accessibilityIdentifier(A11yID.Auth.emailButton)
        }
        .disabled(session.isWorking)
        .opacity(session.isWorking ? 0.6 : 1)
    }

    /// One centred paragraph like the mockup: muted policy line with bold inline links.
    private var footer: some View {
        Text(footerText)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.Brand.muted)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .tint(Tokens.Mono.Brand.text)
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
        link.swiftUI.foregroundColor = Tokens.Mono.Brand.text
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
