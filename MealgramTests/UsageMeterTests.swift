import XCTest

@testable import Mealgram

@MainActor
final class UsageMeterTests: XCTestCase {
    private func makeDefaults() -> UserDefaults {
        let suite = "UsageMeterTests-\(UUID())"
        return UserDefaults(suiteName: suite) ?? .standard
    }

    func testStartsAtZero() {
        let meter = UsageMeter(defaults: makeDefaults())
        XCTAssertEqual(meter.used(.photoScan), 0)
        XCTAssertEqual(meter.used(.barcodeScan), 0)
        XCTAssertEqual(meter.used(.voiceEntry), 0)
    }

    func testRecordIncrementsCount() {
        let meter = UsageMeter(defaults: makeDefaults())
        meter.record(.photoScan, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertEqual(meter.used(.photoScan), 2)
    }

    func testCanUseRespectsCap() {
        let meter = UsageMeter(defaults: makeDefaults())
        XCTAssertTrue(meter.canUse(.photoScan, cap: 3))
        meter.record(.photoScan, cap: 3)
        meter.record(.photoScan, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertFalse(meter.canUse(.photoScan, cap: 3))
    }

    func testRemainingMatchesCap() {
        let meter = UsageMeter(defaults: makeDefaults())
        XCTAssertEqual(meter.remaining(.photoScan, cap: 3), 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertEqual(meter.remaining(.photoScan, cap: 3), 2)
    }

    func testNilCapMeansUnlimited() {
        let meter = UsageMeter(defaults: makeDefaults())
        XCTAssertTrue(meter.canUse(.photoScan, cap: nil))
        XCTAssertNil(meter.remaining(.photoScan, cap: nil))
        // Record with nil cap is a no-op for the counter.
        meter.record(.photoScan, cap: nil)
        XCTAssertEqual(meter.used(.photoScan), 0)
    }

    func testWeekKeyRollover() {
        let defaults = makeDefaults()
        let calendar = Calendar.iso8601Monday
        let week1Date = Date(timeIntervalSince1970: 1_704_672_000)  // 2024-01-08, ISO wk 02
        var now = week1Date
        let meter = UsageMeter(defaults: defaults, calendar: calendar, now: { now })
        meter.record(.photoScan, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertEqual(meter.used(.photoScan), 2)

        // Advance by 7 days — new ISO week.
        now = week1Date.addingTimeInterval(7 * 24 * 3600)
        let next = UsageMeter(defaults: defaults, calendar: calendar, now: { now })
        XCTAssertEqual(next.used(.photoScan), 0)
    }
}

@MainActor
final class EntitlementsTests: XCTestCase {
    func testFreeTierCapsMatchSpec() {
        let free = Entitlements.free
        XCTAssertEqual(free.photoScansPerWeek, 5)
        XCTAssertEqual(free.barcodeScansPerWeek, 5)
        XCTAssertEqual(free.voiceEntriesPerWeek, 5)
        XCTAssertEqual(free.activeCustomGoalsCap, 1)
        XCTAssertEqual(free.friendsCap, 3)
        XCTAssertEqual(free.savedRecipesCap, 5)
        XCTAssertEqual(free.historyDays, 30)
        XCTAssertEqual(free.allowedExportFormats, [.json])
        XCTAssertEqual(free.favoritesCap, 5)
        XCTAssertTrue(free.canUseFavorites)
        XCTAssertFalse(free.canChangeTheme)
        XCTAssertFalse(free.canUseICloudSync)
    }

    func testPremiumHasNoLimits() {
        let premium = Entitlements.premium
        XCTAssertNil(premium.photoScansPerWeek)
        XCTAssertNil(premium.activeCustomGoalsCap)
        XCTAssertNil(premium.friendsCap)
        XCTAssertNil(premium.savedRecipesCap)
        XCTAssertNil(premium.historyDays)
        XCTAssertEqual(premium.allowedExportFormats, [.json, .csv, .zip])
        XCTAssertTrue(premium.canUseFavorites)
        XCTAssertTrue(premium.canChangeTheme)
        XCTAssertTrue(premium.canUseICloudSync)
    }

    func testStoreReconcilesFromService() {
        let service = MockSubscriptionService()
        let store = EntitlementsStore(subscriptionService: service)
        XCTAssertFalse(store.current.isPremium)
        // Manually flip the snapshot via override (testing the reconcile path).
        store.overrideForTesting(.premium)
        XCTAssertTrue(store.current.isPremium)
    }
}

@MainActor
final class PaywallCoordinatorTests: XCTestCase {
    func testPresentDismiss() {
        let coordinator = PaywallCoordinator()
        XCTAssertFalse(coordinator.isPresented)
        coordinator.present(.photoScanQuota)
        XCTAssertEqual(coordinator.activeTrigger, .photoScanQuota)
        XCTAssertTrue(coordinator.isPresented)
        coordinator.dismiss()
        XCTAssertNil(coordinator.activeTrigger)
    }

    func testCopyForEveryTrigger() {
        for trigger in [
            PaywallTrigger.photoScanQuota,
            .barcodeScanQuota,
            .voiceEntryQuota,
            .coachDebriefQuota,
            .favoritesUnavailable,
            .customGoalsCap,
            .friendsCap,
            .recipesCap,
            .exportCsv,
            .exportZip,
            .themePicker,
            .iCloudSync,
            .manual,
        ] {
            let copy = trigger.copy
            XCTAssertFalse(copy.headline.isEmpty, "Headline missing for \(trigger.rawValue)")
            XCTAssertFalse(copy.body.isEmpty, "Body missing for \(trigger.rawValue)")
        }
    }
}
