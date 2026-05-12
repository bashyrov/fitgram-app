import XCTest

@testable import Mealgram

final class NotificationPreferencesStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "NotificationPreferencesStoreTests"

    override func setUp() async throws {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suite)
        defaults = nil
    }

    func testFreshInstallDefaultsToAllChannelsOn() {
        let store = NotificationPreferencesStore(defaults: defaults)
        XCTAssertEqual(store.load(), .default)
    }

    func testRoundTrip() {
        let store = NotificationPreferencesStore(defaults: defaults)
        var prefs = NotificationPlanner.Preferences.default
        prefs.streakRisk = false
        store.save(prefs)
        XCTAssertEqual(store.load(), prefs)
    }

    func testExplicitFalseSticks() {
        let store = NotificationPreferencesStore(defaults: defaults)
        store.save(.allOff)
        XCTAssertEqual(store.load(), .allOff)
    }
}
