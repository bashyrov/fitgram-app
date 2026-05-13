import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    var body: some View {
        ZStack {
            backdrop
            ScrollView {
                VStack(spacing: Tokens.Space.xxl) {
                    Spacer(minLength: Tokens.Space.xl)
                    hero
                    FeatureHighlights()
                        .padding(.top, Tokens.Space.lg)
                    Spacer(minLength: Tokens.Space.lg)
                }
                .padding(.vertical, Tokens.Space.lg)
            }
            VStack {
                Spacer()
                VStack(spacing: Tokens.Space.sm) {
                    PrimaryButton(title: "Zacznijmy", systemImage: "arrow.right", action: onContinue)
                        .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
                    if let onSkip {
                        Button("Pomiń na razie — rozejrzę się", action: onSkip)
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
        }
    }

    // MARK: - Backdrop

    @ViewBuilder
    private var backdrop: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            // Subtle lime gradient blob top-right + accent rose blob bottom-left
            // to lift the page off pure-white without feeling busy.
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 80)
                .offset(x: 160, y: -260)
                .allowsHitTesting(false)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -150, y: 320)
                .allowsHitTesting(false)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary.opacity(0.85),
                                Tokens.Palette.primary,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 168, height: 168)
                    .shadow(color: Tokens.Palette.primary.opacity(0.4), radius: 30, x: 0, y: 12)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 70, weight: .semibold))
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(-12))
            }
            VStack(spacing: Tokens.Space.sm) {
                Text("Cześć!")
                    .font(Tokens.Font.display)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Dodawaj posiłki zdjęciem, głosem albo z naszej bazy. **Bez liczenia, bez stresu.**")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
        }
    }
}

private struct FeatureHighlights: View {
    private struct Highlight: Identifiable {
        let id = UUID()
        let symbol: String
        let title: LocalizedStringKey
        let subtitle: LocalizedStringKey
        let tint: Color
    }

    private let highlights: [Highlight] = [
        .init(
            symbol: "camera.fill",
            title: "Zdjęcie → posiłek",
            subtitle: "Skanuj talerz, AI rozpozna składniki w 5 sekund",
            tint: Tokens.Palette.primary
        ),
        .init(
            symbol: "sparkles",
            title: "Trener Ola",
            subtitle: "Polskie smaki, polskie porcje, wsparcie po polsku",
            tint: Tokens.Palette.accent
        ),
        .init(
            symbol: "flame.fill",
            title: "Bez wyrzutów",
            subtitle: "Wspieramy, świętujemy progres — nie oceniamy potknięć",
            tint: Tokens.Palette.warning
        ),
    ]

    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            ForEach(highlights) { highlight in
                row(highlight)
            }
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    private func row(_ highlight: Highlight) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(highlight.tint.opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: highlight.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(highlight.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(highlight.subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
        )
    }
}
