import Foundation
import OSLog
import StoreKit

/// Native StoreKit 2 backed subscription service. Activates when
/// `AppConfig.isPaymentsEnabled` is true and IAP products exist in App
/// Store Connect (`fitgram_premium_monthly`, `fitgram_premium_yearly`).
///
/// No third-party SDKs — StoreKit 2's `Transaction.currentEntitlements`
/// + `Product.products(for:)` + `Product.purchase()` give us everything
/// we need: purchase, restore, expiration check, trial detection.
@MainActor
@Observable
final class StoreKitSubscriptionService: SubscriptionService {
    static let monthlyProductID = "fitgram_premium_monthly"
    static let yearlyProductID = "fitgram_premium_yearly"

    private(set) var snapshot: SubscriptionSnapshot = .free
    private var products: [String: Product] = [:]
    private let entitlementSyncClient: (any APIClient)?

    init() {
        if let baseURL = AppConfig.workerBaseURL {
            entitlementSyncClient = URLSessionAPIClient(
                baseURL: baseURL,
                interceptors: [AuthInterceptor(), TimeZoneInterceptor(), LoggingInterceptor()]
            )
        } else {
            entitlementSyncClient = nil
        }
        // Long-lived listener for renewals / refunds. Tied to the app
        // lifetime — no need to cancel from deinit (which can't safely
        // touch main-actor state anyway).
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update: update)
            }
        }
        Task { await refresh() }
    }

    func refresh() async {
        await loadProductsIfNeeded()
        snapshot = await computeSnapshot()
    }

    func offerings() async throws -> [SubscriptionOffering] {
        await loadProductsIfNeeded()
        guard !products.isEmpty else {
            Logger.persistence.notice("StoreKit: using local fallback offerings")
            return [SubscriptionOffering.stockAnnual, SubscriptionOffering.stockMonthly]
        }
        let monthlyPrice = products[Self.monthlyProductID]?.price
        return products.values
            .sorted { $0.id < $1.id }
            .map { product in
                var offering = Self.mapToOffering(product)
                if product.subscription?.subscriptionPeriod.unit == .year {
                    offering.monthlyEquivalentLabel = (product.price / 12).formatted(product.priceFormatStyle)
                    if let monthlyPrice, monthlyPrice > 0 {
                        let yearOfMonthly = monthlyPrice * 12
                        let saved = (yearOfMonthly - product.price) / yearOfMonthly * 100
                        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
                        offering.savingsPercent = percent > 0 ? percent : nil
                    }
                }
                return offering
            }
    }

    func purchase(_ offering: SubscriptionOffering) async throws -> SubscriptionSnapshot {
        await loadProductsIfNeeded()
        guard let product = products[offering.productID] else {
            Logger.persistence.error("StoreKit: product unavailable \(offering.productID, privacy: .public)")
            throw PurchaseError.productNotFound(offering.productID)
        }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            await refresh()
            return snapshot
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pendingApproval
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func restore() async throws -> SubscriptionSnapshot {
        try await AppStore.sync()
        await refresh()
        return snapshot
    }

    // MARK: - Internals

    private func loadProductsIfNeeded() async {
        guard products.isEmpty else { return }
        do {
            let fetched = try await Product.products(
                for: [Self.monthlyProductID, Self.yearlyProductID]
            )
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
        } catch {
            Logger.persistence.error("StoreKit: product load failed: \(String(describing: error))")
        }
    }

    private func computeSnapshot() async -> SubscriptionSnapshot {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                transaction.productType == .autoRenewable,
                transaction.revocationDate == nil
            else { continue }
            let willRenew = transaction.expirationDate.map { $0 > Date() } ?? true
            await syncVerifiedEntitlement(transaction)
            return SubscriptionSnapshot(
                isPremium: true,
                activeProductID: transaction.productID,
                expirationDate: transaction.expirationDate,
                willRenew: willRenew,
                isTrial: transaction.offerType == .introductory
            )
        }
        return .free
    }

    private func syncVerifiedEntitlement(_ transaction: Transaction) async {
        guard let entitlementSyncClient else { return }
        struct Payload: Encodable { let transactionID: String }
        struct Response: Decodable, Sendable {
            let isPremium: Bool
            let productID: String
            let expiresAtMs: Int64
        }
        do {
            let endpoint = try Endpoint.json(
                path: "/api/v1/subscription/sync",
                payload: Payload(transactionID: String(transaction.id))
            )
            _ = try await entitlementSyncClient.send(endpoint, expecting: Response.self)
        } catch {
            // StoreKit remains the local source of truth. Server sync is
            // retried on every refresh, purchase, restore, and renewal.
            Logger.networking.notice(
                "Subscription entitlement sync deferred: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private func handle(update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        await transaction.finish()
        await refresh()
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw PurchaseError.failedVerification
        }
    }

    private static func mapToOffering(_ product: Product) -> SubscriptionOffering {
        let monthly = product.id == StoreKitSubscriptionService.monthlyProductID
        return SubscriptionOffering(
            id: monthly ? "monthly" : "annual",
            productID: product.id,
            title: product.displayName,
            priceLabel: product.displayPrice,
            periodLabel: product.subscription?.subscriptionPeriod.localizedLabel ?? "",
            isFeatured: !monthly,
            trialDays: product.subscription?.introductoryOffer?.period.value
        )
    }

    enum PurchaseError: LocalizedError {
        case productNotFound(String)
        case userCancelled
        case pendingApproval
        case failedVerification
        case unknown

        var errorDescription: String? {
            switch self {
            case .productNotFound(let id):
                return String.localizedStringWithFormat(
                    L("Plan %@ niedostępny."),
                    id
                )
            case .userCancelled: return L("Zakup anulowany.")
            case .pendingApproval: return L("Płatność czeka na potwierdzenie.")
            case .failedVerification: return L("Nie udało się zweryfikować zakupu.")
            case .unknown: return L("Something went wrong. Try again.")
            }
        }
    }
}

extension Product.SubscriptionPeriod {
    fileprivate var localizedLabel: String {
        let unit: String
        switch self.unit {
        case .day: unit = value == 1 ? L("dzień") : L("dni")
        case .week: unit = value == 1 ? L("tydzień") : L("tygodnie")
        case .month: unit = L("miesięcznie")
        case .year: unit = L("rocznie")
        @unknown default: unit = ""
        }
        return value > 1 ? "/ \(value) \(unit)" : "/ \(unit)"
    }
}
