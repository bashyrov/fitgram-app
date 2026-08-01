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

    func testCanUseRespectsDailyCap() {
        let meter = UsageMeter(defaults: makeDefaults())
        XCTAssertTrue(meter.canUse(.photoScan, cap: 3))
        meter.record(.photoScan, cap: 3)
        meter.record(.voiceEntry, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertFalse(meter.canUse(.photoScan, cap: 3))
        XCTAssertFalse(meter.canUse(.voiceEntry, cap: 3))
        XCTAssertTrue(meter.canUse(.barcodeScan, cap: nil))
        XCTAssertTrue(meter.canUse(.mealAIRefresh, cap: 3))
        XCTAssertTrue(meter.canUse(.productNutritionLookup, cap: 2))
        XCTAssertTrue(meter.canUse(.olaChef, cap: 1))
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
        // Record with nil cap is a no-op for the visible feature counter.
        meter.record(.photoScan, cap: nil)
        XCTAssertEqual(meter.used(.photoScan), 0)
    }

    func testHiddenAISafetyCapAppliesToPremium() {
        let meter = UsageMeter(defaults: makeDefaults())
        for _ in 0..<FreeTierLimits.aiRequestsSafetyCapPerDay {
            XCTAssertTrue(meter.canUse(.mealAIRefresh, cap: nil))
            meter.record(.mealAIRefresh, cap: nil)
        }
        XCTAssertFalse(meter.canUse(.mealAIRefresh, cap: nil))
        XCTAssertNil(meter.remaining(.mealAIRefresh, cap: nil))
    }

    func testHiddenAISafetyCapIsSharedAcrossAIKinds() {
        let meter = UsageMeter(defaults: makeDefaults())
        for index in 0..<FreeTierLimits.aiRequestsSafetyCapPerDay {
            let kind: UsageMeter.Kind = index.isMultiple(of: 2) ? .photoScan : .productNutritionLookup
            meter.record(kind, cap: nil)
        }
        XCTAssertFalse(meter.canUse(.voiceEntry, cap: nil))
        XCTAssertFalse(meter.canUse(.olaChef, cap: nil))
    }

    func testBarcodeDoesNotConsumeHiddenAISafetyCap() {
        let meter = UsageMeter(defaults: makeDefaults())
        for _ in 0..<(FreeTierLimits.aiRequestsSafetyCapPerDay + 10) {
            meter.record(.barcodeScan, cap: nil)
        }
        XCTAssertTrue(meter.canUse(.photoScan, cap: nil))
        XCTAssertTrue(meter.canUse(.barcodeScan, cap: nil))
    }

    func testDayKeyRollover() {
        let defaults = makeDefaults()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3_600) ?? .current
        let day1Date = Date(timeIntervalSince1970: 1_704_672_000)  // 2024-01-08 01:00 CET
        var now = day1Date
        let meter = UsageMeter(defaults: defaults, calendar: calendar, now: { now })
        meter.record(.photoScan, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertEqual(meter.used(.photoScan), 2)

        // Advance by 1 day — new daily AI allowance.
        now = day1Date.addingTimeInterval(24 * 3600)
        let next = UsageMeter(defaults: defaults, calendar: calendar, now: { now })
        XCTAssertEqual(next.used(.photoScan), 0)
    }

    func testOpenMeterRefreshesWhenLocalDayChanges() {
        let defaults = makeDefaults()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7_200) ?? .current
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 30
        components.hour = 23
        components.minute = 58
        var now = components.date ?? Date()
        let meter = UsageMeter(defaults: defaults, calendar: calendar, now: { now })

        meter.record(.photoScan, cap: 3)
        meter.record(.voiceEntry, cap: 3)
        meter.record(.photoScan, cap: 3)
        XCTAssertFalse(meter.canUse(.photoScan, cap: 3))

        now = now.addingTimeInterval(4 * 60)
        XCTAssertEqual(meter.used(.photoScan), 0)
        XCTAssertTrue(meter.canUse(.voiceEntry, cap: 3))
        XCTAssertTrue(meter.canUse(.barcodeScan, cap: nil))
    }

    func testOlaChefHasSeparateDailyPool() {
        let meter = UsageMeter(defaults: makeDefaults())
        meter.record(.olaChef, cap: 1)
        XCTAssertFalse(meter.canUse(.olaChef, cap: 1))
        XCTAssertTrue(meter.canUse(.photoScan, cap: 3))
        XCTAssertTrue(meter.canUse(.mealAIRefresh, cap: 3))
    }
}

@MainActor
final class EntitlementsTests: XCTestCase {
    func testFreeTierCapsMatchSpec() {
        let free = Entitlements.free
        XCTAssertEqual(free.photoScansPerWeek, 3)
        XCTAssertNil(free.barcodeScansPerWeek)
        XCTAssertEqual(free.voiceEntriesPerWeek, 3)
        XCTAssertEqual(free.mealAIRefreshesPerDay, 3)
        XCTAssertEqual(free.productNutritionLookupsPerDay, 2)
        XCTAssertEqual(free.olaChefRequestsPerDay, 1)
        XCTAssertEqual(free.coachWeeklyDebriefsPerWeek, 0)
        XCTAssertNil(free.activeCustomGoalsCap)
        XCTAssertNil(free.friendsCap)
        XCTAssertEqual(free.savedRecipesCap, 5)
        XCTAssertNil(free.historyDays)
        XCTAssertEqual(free.allowedExportFormats, [.json, .csv, .zip])
        XCTAssertNil(free.favoritesCap)
        XCTAssertTrue(free.canUseFavorites)
        XCTAssertTrue(free.canChangeTheme)
        XCTAssertTrue(free.canUseICloudSync)
        XCTAssertFalse(free.canUseOlaAdvice)
    }

    func testPremiumHasNoLimits() {
        let premium = Entitlements.premium
        XCTAssertNil(premium.photoScansPerWeek)
        XCTAssertNil(premium.mealAIRefreshesPerDay)
        XCTAssertNil(premium.productNutritionLookupsPerDay)
        XCTAssertNil(premium.olaChefRequestsPerDay)
        XCTAssertNil(premium.activeCustomGoalsCap)
        XCTAssertNil(premium.friendsCap)
        XCTAssertNil(premium.savedRecipesCap)
        XCTAssertNil(premium.historyDays)
        XCTAssertEqual(premium.allowedExportFormats, [.json, .csv, .zip])
        XCTAssertTrue(premium.canUseFavorites)
        XCTAssertTrue(premium.canChangeTheme)
        XCTAssertTrue(premium.canUseICloudSync)
        XCTAssertTrue(premium.canUseOlaAdvice)
    }

    func testStoreReconcilesFromService() {
        let service = MockSubscriptionService()
        let store = EntitlementsStore(subscriptionService: service)
        // With IS_PAYMENTS_ENABLED=false (v1 launch posture) the mock
        // service starts the user as premium so the whole app is unlocked.
        // Override the entitlements to free to exercise the reconcile path.
        store.overrideForTesting(.free)
        XCTAssertFalse(store.current.isPremium)
        store.overrideForTesting(.premium)
        XCTAssertTrue(store.current.isPremium)
    }
}

@MainActor
final class PaywallCoordinatorTests: XCTestCase {
    func testPresentDismiss() {
        // Test with the gate forced open — `present()` is a no-op when
        // payments are disabled. Production wiring passes a closure that
        // reads `AppConfig.isPaymentsEnabled` instead.
        let coordinator = PaywallCoordinator(isEnabled: { true })
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
            .mealAIRefreshQuota,
            .productNutritionQuota,
            .olaChefQuota,
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
