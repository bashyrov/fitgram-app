import SwiftData
import XCTest

@testable import Fitgram

@MainActor
final class FreshInstallSessionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suite = ""
    private var tokenStore: TokenStore!

    override func setUp() async throws {
        suite = "FreshInstallSessionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        tokenStore = TokenStore(keychain: Keychain(service: "tests.\(suite)"))
        try tokenStore.save(
            session: AuthCredentials(
                userID: "u1", accessToken: "token", refreshToken: "refresh", expiresAt: nil, provider: .apple))
    }

    override func tearDown() async throws {
        try? tokenStore.clear()
        defaults.removePersistentDomain(forName: suite)
    }

    func testReinstallForgetsTheKeychainSession() throws {
        let container = try PersistenceController.makeInMemory().container

        FitgramApp.forgetSessionFromPreviousInstall(container: container, defaults: defaults, tokenStore: tokenStore)

        XCTAssertNil(try tokenStore.accessToken)
        XCTAssertNil(try tokenStore.userID)
    }

    func testUpdateKeepsTheSession() throws {
        let container = try PersistenceController.makeInMemory().container
        let context = ModelContext(container)
        context.insert(User(remoteID: "u1"))
        try context.save()

        FitgramApp.forgetSessionFromPreviousInstall(container: container, defaults: defaults, tokenStore: tokenStore)

        XCTAssertEqual(try tokenStore.userID, "u1")
    }

    func testRunsOnlyOnTheFirstLaunch() throws {
        let container = try PersistenceController.makeInMemory().container
        defaults.set(true, forKey: FitgramApp.installMarkerKey)

        FitgramApp.forgetSessionFromPreviousInstall(container: container, defaults: defaults, tokenStore: tokenStore)

        XCTAssertEqual(try tokenStore.userID, "u1")
    }
}
