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
            FitgramWordmarkLockup(appeared: appeared)
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
