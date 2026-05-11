import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.xxl) {
                Spacer()
                VStack(spacing: Tokens.Space.lg) {
                    ZStack {
                        Circle()
                            .fill(Tokens.Palette.primarySoft)
                            .frame(width: 160, height: 160)
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .mealgramShadow(Tokens.Shadow.float)

                    Text("Cześć!")
                        .font(Tokens.Font.display)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Dodawaj posiłki zdjęciem, głosem albo z naszej bazy. Bez liczenia, bez stresu.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.xl)
                }
                Spacer()

                FeatureHighlights()

                Spacer()

                PrimaryButton(title: "Zacznijmy", systemImage: "arrow.right", action: onContinue)
                    .padding(.horizontal, Tokens.Space.screenPadding)
            }
            .padding(.vertical, Tokens.Space.xl)
        }
    }
}

private struct FeatureHighlights: View {
    var body: some View {
        VStack(spacing: Tokens.Space.md) {
            highlight(symbol: "camera.fill", text: "Zdjęcie → posiłek w 5 sekund")
            highlight(symbol: "sparkles", text: "Trener Ola, który zna polskie smaki")
            highlight(symbol: "heart.fill", text: "Bez wyrzutów. Wspieramy, nie oceniamy.")
        }
        .padding(.horizontal, Tokens.Space.xl)
    }

    private func highlight(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28)
            Text(text)
                .font(Tokens.Font.callout)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
    }
}
