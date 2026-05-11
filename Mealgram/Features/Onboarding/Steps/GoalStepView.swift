import SwiftUI

struct GoalStepView: View {
    @Binding var goal: GoalKind
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "Jaki masz cel?",
            subtitle: "To pomoże nam ustawić Twoje dzienne wartości. Możesz to zmienić później.",
            primaryTitle: "Dalej",
            primarySystemImage: "arrow.right",
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.md) {
                    OnboardingChoiceCard(
                        symbol: "arrow.down.right",
                        title: "Schudnąć",
                        subtitle: "Łagodny deficyt, długoterminowo",
                        isSelected: goal == .lose,
                        action: { goal = .lose }
                    )
                    OnboardingChoiceCard(
                        symbol: "equal",
                        title: "Utrzymać wagę",
                        subtitle: "Zdrowe nawyki bez zmiany masy",
                        isSelected: goal == .maintain,
                        action: { goal = .maintain }
                    )
                    OnboardingChoiceCard(
                        symbol: "arrow.up.right",
                        title: "Przybrać",
                        subtitle: "Większa porcja energii i białka",
                        isSelected: goal == .gain,
                        action: { goal = .gain }
                    )
                }
            }
        )
    }
}
