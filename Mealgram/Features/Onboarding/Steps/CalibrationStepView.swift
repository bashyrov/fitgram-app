import SwiftUI

/// Pre-Milestone-2.1 mock. We collect a reference-object choice and a
/// "ready to calibrate later" intent — full plate calibration UI ships in
/// Phase 2.
struct CalibrationStepView: View {
    @Binding var profile: OnboardingProfile
    let onContinue: () -> Void

    @State private var reference: ReferenceObjectKind = .creditCard

    var body: some View {
        OnboardingStepScaffold(
            title: "Spersonalizujemy AI",
            subtitle: """
                Każdy talerz i każda dłoń są inne. \
                Z czasem dopasujemy estymacje porcji do Twojej rzeczywistości.
                """,
            primaryTitle: "Dalej",
            primarySystemImage: "arrow.right",
            secondaryTitle: "Zrobię to później",
            secondaryAction: onContinue,
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.md) {
                    OnboardingChoiceCard(
                        symbol: "creditcard.fill",
                        title: "Karta płatnicza",
                        subtitle: "Najczęściej wybierany punkt odniesienia",
                        isSelected: reference == .creditCard,
                        action: { reference = .creditCard }
                    )
                    OnboardingChoiceCard(
                        symbol: "hand.raised.fill",
                        title: "Twoja dłoń",
                        subtitle: "Naturalnie zawsze pod ręką",
                        isSelected: reference == .eatingHand,
                        action: { reference = .eatingHand }
                    )
                    OnboardingChoiceCard(
                        symbol: "fork.knife",
                        title: "Sztućce",
                        subtitle: "Łyżka, widelec — porównujemy z talerzem",
                        isSelected: reference == .fork,
                        action: { reference = .fork }
                    )
                }
            }
        )
    }
}
