import SwiftUI

/// Container view that hosts the onboarding flow. Header carries a back
/// affordance + progress bar; body swaps between step views with a fade
/// transition so it stays calm.
struct OnboardingView: View {
    @Bindable var flow: OnboardingFlow

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.lg) {
                if flow.currentStep != .celebration {
                    header
                }
                stepBody
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.md) {
            Button {
                flow.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle().fill(Tokens.Palette.surfaceMuted)
                    )
            }
            .opacity(flow.canGoBack ? 1 : 0)
            .disabled(!flow.canGoBack)
            .accessibilityLabel(Text("Wróć"))

            OnboardingProgressBar(
                index: flow.currentStep.progressIndex,
                total: flow.currentStep.progressTotal
            )
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.lg)
    }

    @ViewBuilder
    private var stepBody: some View {
        Group {
            switch flow.currentStep {
            case .welcome:
                WelcomeStepView(
                    onContinue: { flow.advance() },
                    onSkip: { flow.skipToEnd() }
                )
            case .goal:
                GoalStepView(goal: $flow.profile.goal) { flow.advance() }
            case .profile:
                ProfileStepView(profile: $flow.profile) { flow.advance() }
            case .dietary:
                DietaryStepView(selected: $flow.profile.dietaryPreferences) { flow.advance() }
            case .firstScan:
                FirstScanStepView { flow.advance() }
            case .calibration:
                CalibrationStepView(
                    profile: $flow.profile,
                    computedGoals: flow.computedGoals
                ) { flow.advance() }
            case .notifications:
                NotificationStepView { flow.advance() }
            case .paywall:
                PaywallStepView { flow.advance() }
            case .celebration:
                CelebrationStepView(
                    displayName: flow.displayName,
                    onContinue: { Task { await flow.complete() } }
                )
            }
        }
        .transition(.opacity)
        .animation(Tokens.Motion.gentle, value: flow.currentStep)
    }
}
