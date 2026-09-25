import SwiftUI

/// Onboarding paywall wrapper. Purchase and restore are handled by
/// PaywallView so the trial flow uses the same StoreKit-backed service
/// as every in-app upgrade surface.
struct PaywallStepView: View {
    let subscriptionService: any SubscriptionService
    let onPurchased: () -> Void
    let onSkip: () -> Void

    var body: some View {
        PaywallView(
            service: subscriptionService,
            onPurchased: { _ in onPurchased() },
            onSkip: onSkip
        )
        .accessibilityIdentifier(A11yID.Onboarding.paywallContinue)
    }
}
