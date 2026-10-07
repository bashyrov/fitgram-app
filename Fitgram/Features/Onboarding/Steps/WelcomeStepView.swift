import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                hero
                    .padding(.top, 16)
                FeatureHighlights()
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.lg)
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            MonoBottomBar {
                MonoButton(title: L("Zacznijmy"), kind: .dark, action: onContinue)
                    .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
            }
        }
        .onAppear {
            withAnimation(Tokens.Motion.gentle.delay(0.12)) {
                appeared = true
            }
        }
    }

    // MARK: - Hero

    /// Dark hero: Fitgram mark, display wordmark and the tagline.
    private var hero: some View {
        VStack(alignment: .leading, spacing: 14) {
            FitgramLogoMark(color: Tokens.Mono.hi)
                .frame(width: 120, height: 56)
            Text(verbatim: "Fitgram")
                .font(Tokens.Font.monoDisplay(36))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(1)
            Text("Twój spokojny plan jedzenia, zdjęć i makro — bez liczenia w głowie.")
                .font(Tokens.Font.manrope(15, weight: 600))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .scaleEffect(appeared ? 1 : 0.97)
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
            symbol: "camera",
            title: "Photo → meal",
            subtitle: "Skan talerza, a potem wybór ogólnie albo składniki",
            tint: Tokens.Palette.primary
        ),
        .init(
            symbol: "sparkles",
            title: "Coach Ola",
            subtitle: "Porady dopasowane do celu, języka i rytmu dnia",
            tint: Tokens.Palette.accent
        ),
        .init(
            symbol: "flame",
            title: "Plan bez presji",
            subtitle: "Streak, freeze i przypomnienia pomagają wrócić do rytmu",
            tint: Tokens.Palette.warning
        ),
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(highlights) { highlight in
                row(highlight)
            }
        }
    }

    private func row(_ highlight: Highlight) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: highlight.symbol, style: .outline, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(highlight.title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(highlight.subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .monoCard(radius: Tokens.Mono.Radius.tile, padding: 0)
        .accessibilityElement(children: .combine)
    }
}
