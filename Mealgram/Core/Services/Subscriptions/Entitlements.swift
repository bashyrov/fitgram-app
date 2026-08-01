import Foundation
import Observation

/// What features are unlocked for the current user. Two factories:
/// `free` and `premium`. Views read flags + limits instead of asking
/// `subscriptionService.snapshot.isPremium` directly so the wiring
/// stays declarative.
struct Entitlements: Equatable, Sendable {
    let isPremium: Bool

    let photoScansPerWeek: Int?
    let barcodeScansPerWeek: Int?
    let voiceEntriesPerWeek: Int?
    let mealAIRefreshesPerDay: Int?
    let productNutritionLookupsPerDay: Int?
    let olaChefRequestsPerDay: Int?
    let coachWeeklyDebriefsPerWeek: Int?

    let activeCustomGoalsCap: Int?
    let savedRecipesCap: Int?
    let friendsCap: Int?
    let favoritesCap: Int?

    let historyDays: Int?
    let allowedExportFormats: Set<ExportFormat>

    let canUseFavorites: Bool
    let canChangeTheme: Bool
    let canUseICloudSync: Bool
    let canUseOlaAdvice: Bool

    static let free = Entitlements(
        isPremium: false,
        photoScansPerWeek: FreeTierLimits.photoScansPerWeek,
        barcodeScansPerWeek: FreeTierLimits.barcodeScansPerWeek,
        voiceEntriesPerWeek: FreeTierLimits.voiceEntriesPerWeek,
        mealAIRefreshesPerDay: FreeTierLimits.aiMealRefreshesPerDay,
        productNutritionLookupsPerDay: FreeTierLimits.aiProductLookupsPerDay,
        olaChefRequestsPerDay: FreeTierLimits.olaChefRequestsPerDay,
        coachWeeklyDebriefsPerWeek: FreeTierLimits.coachWeeklyDebriefsPerWeek,
        activeCustomGoalsCap: FreeTierLimits.activeCustomGoals,
        savedRecipesCap: FreeTierLimits.savedRecipes,
        friendsCap: FreeTierLimits.friendsCount,
        favoritesCap: FreeTierLimits.favorites,
        historyDays: FreeTierLimits.historyDays,
        allowedExportFormats: FreeTierLimits.allowedExportFormats,
        canUseFavorites: FreeTierLimits.canUseFavorites,
        canChangeTheme: FreeTierLimits.canChangeTheme,
        canUseICloudSync: FreeTierLimits.canUseICloudSync,
        canUseOlaAdvice: FreeTierLimits.canUseOlaAdvice
    )

    /// `nil` for every cap means "no limit".
    static let premium = Entitlements(
        isPremium: true,
        photoScansPerWeek: nil,
        barcodeScansPerWeek: nil,
        voiceEntriesPerWeek: nil,
        mealAIRefreshesPerDay: nil,
        productNutritionLookupsPerDay: nil,
        olaChefRequestsPerDay: nil,
        coachWeeklyDebriefsPerWeek: nil,
        activeCustomGoalsCap: nil,
        savedRecipesCap: nil,
        friendsCap: nil,
        favoritesCap: nil,
        historyDays: nil,
        allowedExportFormats: [.json, .csv, .zip],
        canUseFavorites: true,
        canChangeTheme: true,
        canUseICloudSync: true,
        canUseOlaAdvice: true
    )
}

/// Observable bridge between the SubscriptionService snapshot + the
/// rest of the app. Views bind to `current` and re-render when the
/// snapshot flips premium ↔ free.
@MainActor
@Observable
final class EntitlementsStore {
    private(set) var current: Entitlements

    private let subscriptionService: any SubscriptionService

    /// Optional downgrade callback kept for future billing experiments.
    /// With the current unlimited free/trial posture it should not trim
    /// anything because every cap is `nil`.
    var onDowngradeFreeTier: (() -> Void)?

    init(subscriptionService: any SubscriptionService) {
        self.subscriptionService = subscriptionService
        self.current = subscriptionService.snapshot.isPremium ? .premium : .free
    }

    /// Reconciles `current` against the latest snapshot. Called after
    /// purchase/restore/refresh.
    func reconcile() {
        let next: Entitlements = subscriptionService.snapshot.isPremium ? .premium : .free
        guard next != current else { return }
        let wasPremium = current.isPremium
        current = next
        if wasPremium && !next.isPremium {
            onDowngradeFreeTier?()
        }
    }

    /// Test-only override — flip entitlements without touching the
    /// underlying service.
    func overrideForTesting(_ entitlements: Entitlements) {
        current = entitlements
    }
}
