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

    func present(_ trigger: PaywallTrigger) {
        activeTrigger = trigger
    }

    func dismiss() {
        activeTrigger = nil
    }

    var isPresented: Bool {
        activeTrigger != nil
    }
}
