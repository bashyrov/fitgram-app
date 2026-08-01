import SwiftUI

struct GoalStepView: View {
    @Binding var goal: GoalKind
    let onContinue: () -> Void

    var body: some View {
        OnboardingStepScaffold(
            title: "Jaki masz cel?",
            subtitle: "This helps us set your daily targets. You can change it later.",
            primaryTitle: "Next",
            primarySystemImage: "arrow.right",
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.md) {
                    OnboardingChoiceCard(
                        symbol: "arrow.down.right",
                        title: "Lose weight",
                        subtitle: "Gentle deficit, long-term",
                        isSelected: goal == .lose,
                        action: { goal = .lose }
                    )
                    OnboardingChoiceCard(
                        symbol: "arrow.up.right",
                        title: "Gain weight",
                        subtitle: "More energy and protein",
                        isSelected: goal == .gain,
                        action: { goal = .gain }
                    )
                    OnboardingChoiceCard(
                        symbol: "equal",
                        title: "Maintain weight",
                        subtitle: "Zdrowe nawyki bez zmiany masy",
                        isSelected: goal == .maintain,
                        action: { goal = .maintain }
                    )
                    OnboardingChoiceCard(
                        symbol: "heart.text.square",
                        title: "Konkretny cel zdrowotny",
                        subtitle: "E.g. working with a dietician, medical condition",
                        isSelected: goal == .healthCondition,
                        action: { goal = .healthCondition }
                    )
                    OnboardingChoiceCard(
                        symbol: "magnifyingglass",
                        title: "No goal, just tracking",
                        subtitle: "I just want to see what I eat",
                        isSelected: goal == .justTracking,
                        action: { goal = .justTracking }
                    )
                }
            }
        )
    }
}
