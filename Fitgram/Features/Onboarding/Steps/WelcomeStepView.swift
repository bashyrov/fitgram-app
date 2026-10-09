import SwiftUI

/// First onboarding screen: a big Fitgram mark pinned to the left, the
/// wordmark and a one-line promise, plus a few playful stickers.
struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            FitgramLogoMark(color: Tokens.Mono.hi)
                .frame(width: 240, height: 112)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -40)
            Text(verbatim: "FITGRAM")
                .font(Tokens.Font.monoDisplay(58))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 18)
            Text(
                TL(
                    pl: "Licz kalorie zdjęciem.\nBez tabelek, bez spiny.",
                    en: "Count calories with a photo.\nNo spreadsheets, no stress.",
                    uk: "Рахуй калорії по фото.\nБез таблиць і нервів.",
                    ru: "Считай калории по фото.\nБез таблиц и нервов.",
                    es: "Cuenta calorías con una foto.\nSin tablas ni estrés.")
            )
            .font(Tokens.Font.manrope(18, weight: 700))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 8)
            Spacer(minLength: 24)
            StickerCloud(appeared: appeared)
            Spacer(minLength: 24)
            MonoButton(title: L("Zacznijmy"), kind: .dark, action: onContinue)
                .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Tokens.Palette.background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
                appeared = true
            }
        }
    }
}

/// Three tilted stickers that pop in one after another.
private struct StickerCloud: View {
    let appeared: Bool

    private struct Sticker {
        let emoji: String
        let text: String
        let fill: Color
        let ink: Color
        let angle: Double
        var outlined = false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sticker(
                Sticker(
                    emoji: "📸",
                    text: TL(
                        pl: "pyk → 420 kcal", en: "snap → 420 kcal", uk: "клац → 420 ккал", ru: "щёлк → 420 ккал",
                        es: "clic → 420 kcal"),
                    fill: Tokens.Mono.hi, ink: Tokens.Mono.onHi, angle: -4),
                index: 0)
            sticker(
                Sticker(
                    emoji: "🥟",
                    text: TL(
                        pl: "pierogi też się liczą", en: "pierogi count too", uk: "вареники теж рахуються",
                        ru: "вареники тоже считаются", es: "los pierogi también cuentan"),
                    fill: Tokens.Mono.hero, ink: Tokens.Mono.onHero, angle: 3),
                index: 1
            )
            .padding(.leading, 36)
            sticker(
                Sticker(
                    emoji: "🔥",
                    text: TL(
                        pl: "12 dni z rzędu", en: "12 days in a row", uk: "12 днів поспіль", ru: "12 дней подряд",
                        es: "12 días seguidos"),
                    fill: Tokens.Palette.surface, ink: Tokens.Palette.ink, angle: -2, outlined: true),
                index: 2
            )
            .padding(.leading, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private func sticker(_ sticker: Sticker, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(verbatim: sticker.emoji)
                .font(.system(size: 20))
            Text(sticker.text)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(sticker.ink)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(Capsule().fill(sticker.fill))
        .overlay(Capsule().stroke(sticker.outlined ? Tokens.Mono.line2 : .clear, lineWidth: 1))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .rotationEffect(.degrees(appeared ? sticker.angle : 0))
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.6).delay(0.35 + Double(index) * 0.12), value: appeared)
    }
}
