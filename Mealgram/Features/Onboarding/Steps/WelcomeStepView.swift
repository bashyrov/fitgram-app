import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    @State private var appeared = false

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
                // Reserve room for the floating bottom CTA so the last
                // highlight isn't hidden under it.
                .padding(.bottom, 120)
            }
            VStack {
                Spacer()
                VStack(spacing: Tokens.Space.sm) {
                    PrimaryButton(title: "Zacznijmy", systemImage: "arrow.right", action: onContinue)
                        .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xl)
            }
        }
        .onAppear {
            withAnimation(Tokens.Motion.gentle.delay(0.12)) {
                appeared = true
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
        VStack(spacing: Tokens.Space.xl) {
            onboardingDevicePreview
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 18)
                .scaleEffect(appeared ? 1 : 0.96)
            VStack(spacing: Tokens.Space.sm) {
                Text("Mealgram")
                    .font(Tokens.Font.display)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Twój spokojny plan jedzenia, zdjęć i makro — bez liczenia w głowie.")
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Tokens.Space.xl)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
    }

    private var onboardingDevicePreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: 220, height: 300)
                .overlay {
                    RoundedRectangle(cornerRadius: 38, style: .continuous)
                        .strokeBorder(.white.opacity(0.62), lineWidth: 1)
                }
                .shadow(color: Tokens.Palette.primary.opacity(0.24), radius: 32, y: 18)

            VStack(spacing: Tokens.Space.md) {
                Capsule()
                    .fill(Tokens.Palette.ink.opacity(0.14))
                    .frame(width: 58, height: 5)
                    .padding(.top, Tokens.Space.md)

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.7), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: 0.72)
                        .stroke(Tokens.Palette.primary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .frame(width: 68, height: 68)
                        .background(.regularMaterial, in: Circle())
                }
                .frame(width: 122, height: 122)

                VStack(spacing: 8) {
                    previewBar(width: 136, color: Tokens.Palette.primary)
                    previewBar(width: 112, color: Tokens.Palette.warning)
                    previewBar(width: 126, color: Tokens.Palette.accent)
                }

                HStack(spacing: 8) {
                    previewChip(symbol: "camera.fill", color: Tokens.Palette.primary)
                    previewChip(symbol: "waveform", color: Tokens.Palette.warning)
                    previewChip(symbol: "sparkles", color: Tokens.Palette.accent)
                }
                Spacer(minLength: Tokens.Space.md)
            }
            .padding(Tokens.Space.md)
        }
    }

    private func previewBar(width: CGFloat, color: Color) -> some View {
        Capsule()
            .fill(color.opacity(0.22))
            .frame(width: width, height: 8)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(color)
                    .frame(width: width * 0.68, height: 8)
            }
    }

    private func previewChip(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 38, height: 38)
            .background(.regularMaterial, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.5), lineWidth: 0.7))
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
            symbol: "flame.fill",
            title: "Plan bez presji",
            subtitle: "Streak, freeze i przypomnienia pomagają wrócić do rytmu",
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
