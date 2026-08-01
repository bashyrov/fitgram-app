import Foundation
import Observation

/// Single point for "raise the upgrade sheet from anywhere". A feature
/// view holding nothing more than this coordinator can hit
/// `coordinator.present(.photoScanQuota)` and let the root view layer
/// the sheet on top of whatever the user is doing.
@MainActor
@Observable
final class PaywallCoordinator {
    private(set) var activeTrigger: PaywallTrigger?

    /// Injected at init so tests can exercise the present/dismiss state
    /// machine without depending on the `IS_PAYMENTS_ENABLED` build flag.
    /// Production composition root passes the default closure that reads
    /// `AppConfig`.
    private let isEnabled: () -> Bool

    init(isEnabled: @escaping () -> Bool = { AppConfig.isPaymentsEnabled }) {
        self.isEnabled = isEnabled
    }

    func present(_ trigger: PaywallTrigger) {
        // v1 launch posture: payments disabled → every feature is free,
        // so no paywall ever shows. Flip `IS_PAYMENTS_ENABLED` to true
        // once IAP products are live in App Store Connect.
        guard isEnabled() else { return }
        activeTrigger = trigger
    }

    func dismiss() {
        activeTrigger = nil
    }

    var isPresented: Bool {
        activeTrigger != nil
    }
}
