import SwiftUI

/// First onboarding screen: the FIT mark and "GRAM" spanning the full
/// width over a striped backdrop of faint, randomly offset FITGRAM rows.
struct WelcomeStepView: View {
    let onContinue: () -> Void
    var onSkip: (() -> Void)?

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 24)
            FitgramLogoMark(color: Tokens.Mono.hi)
                .aspectRatio(240.0 / 112.0, contentMode: .fit)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : -60)
            Text(verbatim: "GRAM")
                .font(Tokens.Font.monoDisplay(320))
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(1)
                .minimumScaleFactor(0.05)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
                .opacity(appeared ? 1 : 0)
                .offset(x: appeared ? 0 : 60)
            Text(
                TL(
                    pl: "Licz kalorie zdjęciem. Bez tabelek, bez spiny.",
                    en: "Count calories with a photo. No spreadsheets, no stress.",
                    uk: "Рахуй калорії по фото. Без таблиць і нервів.",
                    ru: "Считай калории по фото. Без таблиц и нервов.",
                    es: "Cuenta calorías con una foto. Sin tablas ni estrés.")
            )
            .font(Tokens.Font.manrope(26, weight: 800))
            .foregroundStyle(Tokens.Mono.heroMuted)
            .lineLimit(2)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .opacity(appeared ? 1 : 0)
            Spacer(minLength: 24)
            MonoButton(title: L("Zacznijmy"), kind: .hi, action: onContinue)
                .accessibilityIdentifier(A11yID.Onboarding.welcomeStart)
                .padding(.bottom, 8)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(WordmarkStripes().ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appeared = true
            }
        }
    }
}

/// Alternating dark bands, each carrying one "FITGRAMFITGRAM…" row at 10 %
/// opacity. Rows start at scattered offsets and run past both edges.
private struct WordmarkStripes: View {
    private static let bandHeight: CGFloat = 58
    /// Fixed pseudo-random offsets (fraction of one word) and repeat
    /// counts, so the pattern is chaotic but identical on every launch.
    private static let offsets: [Double] = [0.62, 0.08, 0.91, 0.37, 0.74, 0.19, 0.55, 0.97, 0.28, 0.83, 0.44, 0.03]
    private static let repeats = [5, 6, 4, 6, 5, 4, 6, 5, 4, 6, 5, 6]

    var body: some View {
        GeometryReader { proxy in
            let rows = Int((proxy.size.height / Self.bandHeight).rounded(.up))
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<rows, id: \.self) { row in
                    band(row)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
            .clipped()
        }
        .background(Tokens.Mono.hero)
        .accessibilityHidden(true)
    }

    private func band(_ row: Int) -> some View {
        let offset = Self.offsets[row % Self.offsets.count]
        let count = Self.repeats[row % Self.repeats.count]
        // One "FITGRAM" at this size is ~190 pt wide; shift left by a
        // fraction of it so word starts never line up between rows.
        return Text(verbatim: String(repeating: "FITGRAM", count: count))
            .font(Tokens.Font.monoDisplay(44))
            .foregroundStyle(Tokens.Mono.onHero.opacity(0.10))
            .lineLimit(1)
            .fixedSize()
            .offset(x: -CGFloat(offset) * 190 - 30)
            .frame(height: Self.bandHeight, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(row.isMultiple(of: 2) ? Color.clear : Tokens.Mono.onHero.opacity(0.035))
    }
}
