import SwiftUI

/// Container view that hosts the onboarding flow. Header carries a back
/// affordance + progress bar; body swaps between step views with a fade
/// transition so it stays calm.
struct OnboardingView: View {
    @Bindable var flow: OnboardingFlow
    let subscriptionService: any SubscriptionService

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
            .accessibilityLabel(Text("Back"))

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
                    onSkip: nil
                )
            case .account:
                AccountStepView(profile: $flow.profile) { flow.advance() }
            case .goal:
                GoalStepView(goal: $flow.profile.goal) { flow.advance() }
            case .profile:
                ProfileStepView(profile: $flow.profile) { flow.advance() }
            case .pace:
                PaceStepView(profile: $flow.profile) { flow.advance() }
            case .dietary:
                DietaryStepView(selected: $flow.profile.dietaryPreferences) { flow.advance() }
            case .firstScan:
                FirstScanStepView { flow.advance() }
            case .calibration:
                // Always rebuild from the rule-based generator at render so
                // the page tracks the in-app language picker even mid-flow.
                // (Worker copy is still fetched in the background for the
                // analytics/source attribution path.)
                CalibrationStepView(
                    profile: $flow.profile,
                    computedTargets: flow.computedTargets,
                    recommendations: flow.profile.recommendationsRequest
                        .map { RuleBasedRecommendationsService.buildSync(for: $0) },
                    isLoadingRecommendations: flow.isLoadingRecommendations
                ) { flow.advance() }
                .task(id: flow.currentStep) {
                    await flow.loadRecommendationsIfNeeded()
                }
            case .notifications:
                NotificationStepView { flow.advance() }
            case .paywall:
                PaywallStepView(
                    subscriptionService: subscriptionService,
                    onPurchased: { flow.advance() },
                    onSkip: { flow.advance() }
                )
            case .celebration:
                CelebrationStepView(
                    displayName: flow.displayName,
                    onContinue: { Task { await flow.complete() } }
                )
            }
        }
        .id(flow.currentStep)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .move(edge: .trailing)),
                removal: .opacity.combined(with: .move(edge: .leading))
            )
        )
        .animation(Tokens.Motion.gentle, value: flow.currentStep)
    }
}
