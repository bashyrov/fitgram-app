import Foundation
import OSLog

/// Provider-agnostic interface for the premium-subscription feature.
/// `StoreKitSubscriptionService` powers production purchases; the mock
/// implementation stays available for previews, DEBUG bypasses, and tests.
@MainActor
protocol SubscriptionService: Sendable {
    /// Currently published entitlement snapshot. Views @Observable-bind
    /// to its `isPremium` for gating.
    var snapshot: SubscriptionSnapshot { get }

    /// Refresh from the provider (cached customer info or remote pull).
    func refresh() async

    /// Fetches available offerings — packages the user can buy.
    func offerings() async throws -> [SubscriptionOffering]

    /// Initiates purchase. Implementation handles StoreKit interaction
    /// + receipt validation via the provider.
    func purchase(_ offering: SubscriptionOffering) async throws -> SubscriptionSnapshot

    /// "Restore Purchases" — required by App Store guideline 3.1.1.
    func restore() async throws -> SubscriptionSnapshot
}

/// Snapshot of the user's subscription state. Views read `isPremium` to
/// gate features.
struct SubscriptionSnapshot: Equatable, Sendable {
    var isPremium: Bool
    var activeProductID: String?
    var expirationDate: Date?
    var willRenew: Bool
    var isTrial: Bool

    static let free = SubscriptionSnapshot(
        isPremium: false,
        activeProductID: nil,
        expirationDate: nil,
        willRenew: false,
        isTrial: false
    )

    static let premiumMock = SubscriptionSnapshot(
        isPremium: true,
        activeProductID: "fitgram_premium_monthly",
        expirationDate: Date().addingTimeInterval(30 * 24 * 3600),
        willRenew: true,
        isTrial: false
    )
}

/// A purchasable plan surfaced from the provider's offerings.
struct SubscriptionOffering: Identifiable, Equatable, Sendable {
    let id: String
    let productID: String
    let title: String
    let priceLabel: String
    let periodLabel: String
    let isFeatured: Bool
    let trialDays: Int?
    /// Annual plans: the price spread per month (e.g. "16,67 zł").
    var monthlyEquivalentLabel: String?
    /// Annual plans: percent saved versus paying monthly for a year.
    var savingsPercent: Int?

    /// Price per month as the paywall leads with it: the monthly plan's own
    /// price, or the annual price spread over 12 months.
    var perMonthLabel: String? {
        monthlyEquivalentLabel ?? (id == "monthly" ? priceLabel : nil)
    }

    /// Fallback plans shown only when StoreKit returns no products (e.g. a
    /// local build without a StoreKit config). Real prices always come from
    /// App Store Connect via `Product.displayPrice`; these mirror the USA tier.
    static let stockMonthly = SubscriptionOffering(
        id: "monthly",
        productID: "fitgram_premium_monthly",
        title: L("Monthly"),
        priceLabel: "$4.99",
        periodLabel: L("/ month"),
        isFeatured: false,
        trialDays: 7
    )

    static let stockAnnual = SubscriptionOffering(
        id: "annual",
        productID: "fitgram_premium_yearly",
        title: L("Yearly"),
        priceLabel: "$44.99",
        periodLabel: L("/ year"),
        isFeatured: true,
        trialDays: 7,
        monthlyEquivalentLabel: "$3.75",
        savingsPercent: 25
    )
}

/// Development-only implementation. Lets the paywall UI render full state
/// machines in previews and tests without talking to App Store servers.
/// New accounts must still start free; tests and previews that need Pro
/// opt into the premium snapshot explicitly.
@MainActor
@Observable
final class MockSubscriptionService: SubscriptionService {
    private(set) var snapshot: SubscriptionSnapshot

    init(initialSnapshot: SubscriptionSnapshot = .free) {
        self.snapshot = initialSnapshot
    }

    func refresh() async {
        // Inert. Mock starts from its injected snapshot; tests/previews
        // bump it manually or call `purchase(_:)`.
    }

    func offerings() async throws -> [SubscriptionOffering] {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
    }

    func purchase(_ offering: SubscriptionOffering) async throws -> SubscriptionSnapshot {
        try? await Task.sleep(nanoseconds: 400_000_000)
        snapshot = SubscriptionSnapshot(
            isPremium: true,
            activeProductID: offering.productID,
            expirationDate: Date().addingTimeInterval(offering.id == "annual" ? 365 : 30 * 24 * 3600),
            willRenew: true,
            isTrial: offering.trialDays != nil
        )
        Logger.persistence.notice("Mock purchase \(offering.productID, privacy: .public)")
        return snapshot
    }

    func restore() async throws -> SubscriptionSnapshot {
        try? await Task.sleep(nanoseconds: 300_000_000)
        return snapshot
    }
}

/// Scaffold for the real RevenueCat-backed service. Activated by:
///
///   1. Adding the package in `project.yml`:
///        packages:
///          RevenueCat:
///            url: https://github.com/RevenueCat/purchases-ios-spm
///            from: "5.0.0"
///   2. `import RevenueCat` here and remove the `#if false` guards.
///   3. Setting the API key in `FitgramApp.init()` via xcconfig:
///        Purchases.configure(withAPIKey: AppConfig.revenueCatKey)
///   4. Creating products `fitgram_premium_monthly` + `fitgram_premium_yearly`
///      in App Store Connect, importing them in the RevenueCat dashboard,
///      attaching them to the `premium` entitlement on the `default`
///      offering.
///
/// Keep `MockSubscriptionService` for SwiftUI previews + unit tests.
@MainActor
final class RevenueCatSubscriptionService: SubscriptionService {
    let entitlementID: String
    private(set) var snapshot: SubscriptionSnapshot = .free

    init(entitlementID: String = "premium") {
        self.entitlementID = entitlementID
    }

    func refresh() async {
        // Once SDK is wired:
        //   guard let info = try? await Purchases.shared.customerInfo() else { return }
        //   snapshot = Self.map(customerInfo: info, entitlement: entitlementID)
        snapshot = .free
    }

    func offerings() async throws -> [SubscriptionOffering] {
        // Once SDK is wired:
        //   let offerings = try await Purchases.shared.offerings()
        //   guard let current = offerings.current else {
        //       throw SubscriptionError.offeringsUnavailable
        //   }
        //   return current.availablePackages.map(Self.map(package:))
        [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
    }

    func purchase(_ offering: SubscriptionOffering) async throws -> SubscriptionSnapshot {
        // Once SDK is wired:
        //   guard let package = try await package(matching: offering) else {
        //       throw SubscriptionError.packageNotFound
        //   }
        //   let result = try await Purchases.shared.purchase(package: package)
        //   snapshot = Self.map(customerInfo: result.customerInfo, entitlement: entitlementID)
        //   return snapshot
        throw SubscriptionError.sdkNotConfigured
    }

    func restore() async throws -> SubscriptionSnapshot {
        // Once SDK is wired:
        //   let info = try await Purchases.shared.restorePurchases()
        //   snapshot = Self.map(customerInfo: info, entitlement: entitlementID)
        //   return snapshot
        throw SubscriptionError.sdkNotConfigured
    }

    enum SubscriptionError: Error, Equatable {
        case sdkNotConfigured
        case offeringsUnavailable
        case packageNotFound
    }
}
