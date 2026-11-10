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
    @ObservationIgnored private var accountObserver: NSObjectProtocol?

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
        // Another account signed in: its entitlement may differ.
        accountObserver = NotificationCenter.default.addObserver(
            forName: .fitgramAccountDidChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        await refresh(claimingForThisAccount: false)
    }

    private func refresh(claimingForThisAccount claim: Bool) async {
        await loadProductsIfNeeded()
        snapshot = await computeSnapshot(claimingForThisAccount: claim)
    }

    func offerings() async throws -> [SubscriptionOffering] {
        await loadProductsIfNeeded()
        guard !products.isEmpty else {
            // Never invent prices: an empty list makes the paywall offer a retry.
            Logger.persistence.notice("StoreKit: no products returned")
            return []
        }
        let monthlyPrice = products[Self.monthlyProductID]?.price
        // Apple grants one introductory offer per subscription group and
        // Apple ID; past trials (even from a deleted Fitgram account) count.
        let trialEligible = await products.values.first?.subscription?.isEligibleForIntroOffer ?? false
        return products.values
            // Yearly (featured, cheapest per month) first.
            .sorted { lhs, rhs in
                (lhs.subscription?.subscriptionPeriod.unit == .year ? 0 : 1, lhs.id)
                    < (rhs.subscription?.subscriptionPeriod.unit == .year ? 0 : 1, rhs.id)
            }
            .map { product in
                var offering = Self.mapToOffering(product)
                if !trialEligible {
                    offering.trialDays = nil
                }
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
        var options: Set<Product.PurchaseOption> = []
        if let token = Self.currentAccountToken {
            options.insert(.appAccountToken(token))
        }
        let result = try await product.purchase(options: options)
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
            // Bought (or re-confirmed, when the Apple ID already had it)
            // from this account: the subscription belongs here now.
            await refresh(claimingForThisAccount: true)
            return snapshot
        case .userCancelled:
            // Apple answers "You're already subscribed" when this Apple ID
            // has the plan (maybe used by another Fitgram account); that
            // sheet closes as a cancel. Claim the existing one instead.
            await refresh(claimingForThisAccount: true)
            if snapshot.isPremium { return snapshot }
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pendingApproval
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func restore() async throws -> SubscriptionSnapshot {
        try await AppStore.sync()
        // "Restore" moves the Apple ID's subscription to this account, even
        // if another Fitgram account used it before.
        await refresh(claimingForThisAccount: true)
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

    private func computeSnapshot(claimingForThisAccount claim: Bool) async -> SubscriptionSnapshot {
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                transaction.productType == .autoRenewable,
                transaction.revocationDate == nil
            else { continue }
            // StoreKit entitlements belong to the Apple ID, not to the
            // Fitgram account: every account signed in on this iPhone would
            // see the same purchase. Purchases carry the buyer's account id
            // (appAccountToken); older ones are claimed by the first account
            // the server links them to.
            if !claim, let token = transaction.appAccountToken, token != Self.currentAccountToken { continue }
            guard await syncVerifiedEntitlement(transaction, transfer: claim) != .linkedToAnotherAccount else {
                continue
            }
            let willRenew = await Self.willAutoRenew(transaction, product: products[transaction.productID])
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

    private enum SyncOutcome {
        case linked
        case linkedToAnotherAccount
        case unknown
    }

    /// The signed-in Fitgram account as an App Store `appAccountToken`
    /// (Supabase user ids are UUIDs).
    private static var currentAccountToken: UUID? {
        UUID(uuidString: AccountScope.currentUserID)
    }

    private static func willAutoRenew(_ transaction: Transaction, product: Product?) async -> Bool {
        let statuses = (try? await product?.subscription?.status) ?? []
        for status in statuses {
            guard case .verified(let current) = status.transaction,
                current.originalID == transaction.originalID,
                case .verified(let renewal) = status.renewalInfo
            else { continue }
            return renewal.willAutoRenew
        }
        return true
    }

    @discardableResult
    private func syncVerifiedEntitlement(_ transaction: Transaction, transfer: Bool) async -> SyncOutcome {
        guard let entitlementSyncClient else { return .unknown }
        struct Payload: Encodable {
            let transactionID: String
            let transfer: Bool
        }
        // Decoded with convertFromSnakeCase: "product_id" becomes
        // "productId", so the property must be spelled that way.
        struct Response: Decodable, Sendable {
            let isPremium: Bool
            let productId: String
            let expiresAtMs: Int64
        }
        do {
            let endpoint = try Endpoint.json(
                path: "/api/v1/subscription/sync",
                payload: Payload(transactionID: String(transaction.id), transfer: transfer)
            )
            _ = try await entitlementSyncClient.send(endpoint, expecting: Response.self)
            return .linked
        } catch APIError.http(let status, _) where status == 409 || status == 403 {
            // 409: this purchase already belongs to another Fitgram account.
            // 403: it was bought for another account (appAccountToken).
            return .linkedToAnotherAccount
        } catch {
            // StoreKit remains the local source of truth. Server sync is
            // retried on every refresh, purchase, restore, and renewal.
            Logger.networking.notice(
                "Subscription entitlement sync deferred: \(String(describing: error), privacy: .public)"
            )
            return .unknown
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
            // Brand plan names stay English in every locale; ASC's localized
            // display names ("… на месяц") read as half-translated.
            title: monthly ? SubscriptionOffering.monthlyTitle : SubscriptionOffering.yearlyTitle,
            priceLabel: product.displayPrice,
            periodLabel: product.subscription?.subscriptionPeriod.localizedLabel ?? "",
            isFeatured: !monthly,
            trialDays: product.subscription?.introductoryOffer
                .flatMap { $0.paymentMode == .freeTrial ? $0.period.approximateDays : nil }
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
        if value == 1, self.unit == .month { return L("/ month") }
        if value == 1, self.unit == .year { return L("/ year") }
        return value > 1 ? "/ \(value) \(unit)" : "/ \(unit)"
    }

    /// Trial length in days — a one-week trial reports `value == 1`, `unit == .week`.
    fileprivate var approximateDays: Int {
        switch unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return value
        }
    }
}
