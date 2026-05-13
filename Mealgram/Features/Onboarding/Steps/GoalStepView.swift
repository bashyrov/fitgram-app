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
                        symbol: "arrow.up.right",
                        title: "Nabrać masy",
                        subtitle: "Większa porcja energii i białka",
                        isSelected: goal == .gain,
                        action: { goal = .gain }
                    )
                    OnboardingChoiceCard(
                        symbol: "equal",
                        title: "Utrzymać wagę",
                        subtitle: "Zdrowe nawyki bez zmiany masy",
                        isSelected: goal == .maintain,
                        action: { goal = .maintain }
                    )
                    OnboardingChoiceCard(
                        symbol: "heart.text.square",
                        title: "Konkretny cel zdrowotny",
                        subtitle: "Np. współpraca z dietetykiem, choroba",
                        isSelected: goal == .healthCondition,
                        action: { goal = .healthCondition }
                    )
                    OnboardingChoiceCard(
                        symbol: "magnifyingglass",
                        title: "Bez celu, tylko śledzenie",
                        subtitle: "Po prostu chcę widzieć, co jem",
                        isSelected: goal == .justTracking,
                        action: { goal = .justTracking }
                    )
                }
            }
        )
    }
}
