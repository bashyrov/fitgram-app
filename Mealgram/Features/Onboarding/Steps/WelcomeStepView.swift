import SwiftUI

/// Cinematic welcome — full-bleed dark hero with a kerned serif headline
/// and a single hard CTA. No emojis, no rounded cards: editorial first
/// impression that signals "this app is for adults who pay".
struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                hero(geometry: geometry)
                contentStack
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Hero backdrop

    private func hero(geometry: GeometryProxy) -> some View {
        ZStack {
            Tokens.Palette.ink
                .ignoresSafeArea()
            LinearGradient(
                colors: [
                    Tokens.Palette.primary.opacity(0.45),
                    Tokens.Palette.primary.opacity(0.0),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            // Subtle film-grain via concentric noise circles
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.22))
                .frame(width: geometry.size.width * 1.4)
                .blur(radius: 100)
                .offset(x: -geometry.size.width * 0.5, y: -geometry.size.height * 0.45)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.18))
                .frame(width: geometry.size.width * 0.9)
                .blur(radius: 90)
                .offset(x: geometry.size.width * 0.4, y: geometry.size.height * 0.35)
        }
    }

    // MARK: - Content

    private var contentStack: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: Tokens.Space.xl) {
                eyebrow
                editorialHeadline
                bodyParagraph
                badges
            }
            .padding(.horizontal, Tokens.Space.screenPadding + 4)
            Spacer()
            ctaStack
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
        }
    }

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Tokens.Palette.primary)
                .frame(width: 6, height: 6)
            Text("Premium · 2026")
                .font(.system(size: 11, weight: .heavy))
                .textCase(.uppercase)
                .tracking(2.0)
                .foregroundStyle(Tokens.Palette.background.opacity(0.7))
        }
    }

    private var editorialHeadline: some View {
        VStack(alignment: .leading, spacing: -4) {
            Text("Twoja kuchnia,")
                .font(.system(size: 52, weight: .heavy, design: .serif))
                .foregroundStyle(Tokens.Palette.background)
            Text("Twoja waga.")
                .font(.system(size: 52, weight: .heavy, design: .serif))
                .foregroundStyle(Tokens.Palette.primary)
                .italic()
        }
        .lineSpacing(-8)
        .padding(.bottom, 4)
    }

    private var bodyParagraph: some View {
        Text(
            "Mealgram analizuje to, co jesz, używając AI **Gemini Pro**. "
                + "Bez liczenia ręcznego, bez wyrzutów. Tylko Ty, talerz i wynik."
        )
        .font(.system(size: 16, weight: .regular))
        .lineSpacing(4)
        .foregroundStyle(Tokens.Palette.background.opacity(0.78))
        .frame(maxWidth: 320, alignment: .leading)
    }

    private var badges: some View {
        HStack(spacing: 8) {
            badge("AI Gemini Pro")
            badge("160+ PL dań")
            badge("HealthKit")
        }
    }

    private func badge(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(Tokens.Palette.background)
            .background(
                Capsule().strokeBorder(Tokens.Palette.background.opacity(0.3), lineWidth: 1)
            )
    }

    private var ctaStack: some View {
        VStack(spacing: Tokens.Space.md) {
            Button(action: onContinue) {
                HStack {
                    Text("Zaczynam")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, Tokens.Space.xl)
                .frame(height: 60)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                        .fill(Tokens.Palette.background)
                )
                .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)

            if let onSkip {
                Button("Już mam konto", action: onSkip)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Tokens.Palette.background.opacity(0.6))
            }
        }
    }
}
