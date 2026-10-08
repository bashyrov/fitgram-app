import Foundation

/// The one place the app checks and spends the free weekly AI pool. Every
/// AI network call goes through it (meal text analysis, save-time nutrition
/// completion, photo scans), so a free user can never spend more than
/// `FreeTierLimits.aiActionsPerWeek` from this device. The Worker enforces
/// the same pool per account and wins whenever the two disagree.
@MainActor
final class AIQuotaGate {
    private let usageMeter: UsageMeter
    private let entitlementsStore: EntitlementsStore
    private let paywallCoordinator: PaywallCoordinator?

    init(usageMeter: UsageMeter, entitlementsStore: EntitlementsStore, paywallCoordinator: PaywallCoordinator?) {
        self.usageMeter = usageMeter
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
    }

    /// `nil` = unlimited (Pro).
    var cap: Int? { entitlementsStore.current.aiActionsPerWeek }

    /// What is left of this week's pool; `nil` for Pro.
    var remaining: Int? { usageMeter.remaining(.mealAIRefresh, cap: cap) }

    /// Call right before an AI request. Shows the paywall and returns false
    /// once the pool is empty.
    func allows(_ trigger: PaywallTrigger) -> Bool {
        if usageMeter.canUse(.mealAIRefresh, cap: cap) { return true }
        Haptics.light()
        paywallCoordinator?.present(trigger)
        return false
    }

    /// Call once per AI request that actually reached the model.
    func spend(_ kind: UsageMeter.Kind) {
        usageMeter.record(kind, cap: cap)
    }

    /// The Worker refused with its free-tier limit (e.g. after a reinstall
    /// reset the local counter): trust it and show the paywall.
    func serverReportedExhausted(_ trigger: PaywallTrigger) {
        guard let cap else { return }
        usageMeter.markExhausted(.mealAIRefresh, cap: cap)
        paywallCoordinator?.present(trigger)
    }
}
