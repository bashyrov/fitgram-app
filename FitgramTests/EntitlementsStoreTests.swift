import XCTest

@testable import Fitgram

@MainActor
final class EntitlementsStoreTests: XCTestCase {
    /// StoreKit restores the subscription after launch; the store must pick
    /// it up without the paywall calling `reconcile()`.
    func testFollowsSnapshotRestoredAfterLaunch() async throws {
        let service = MockSubscriptionService()
        let store = EntitlementsStore(subscriptionService: service)
        XCTAssertFalse(store.current.isPremium)

        _ = try await service.purchase(.stockMonthly)
        for _ in 0..<50 where !store.current.isPremium {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(store.current.isPremium)
    }

    func testStartsPremiumWhenSnapshotAlreadyPremium() {
        let store = EntitlementsStore(subscriptionService: MockSubscriptionService(initialSnapshot: .premiumMock))
        XCTAssertTrue(store.current.isPremium)
    }

    func testRefreshReconciles() async {
        let store = EntitlementsStore(subscriptionService: MockSubscriptionService(initialSnapshot: .premiumMock))
        store.overrideForTesting(.free)
        await store.refresh()
        XCTAssertTrue(store.current.isPremium)
    }
}
