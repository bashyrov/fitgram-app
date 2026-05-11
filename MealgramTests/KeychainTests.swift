import XCTest

@testable import Mealgram

/// Each test isolates itself on a unique service name so parallel test runs
/// don't trample each other's keychain entries.
final class KeychainTests: XCTestCase {
    private func makeKeychain(_ function: String = #function) -> Keychain {
        Keychain(service: "app.mealgram.tests.\(function)")
    }

    override func tearDownWithError() throws {
        // Wipe any stragglers in case a test failed midway.
        try? makeKeychain().removeAll()
    }

    func testWriteReadRoundTrip() throws {
        let keychain = makeKeychain()
        defer { try? keychain.removeAll() }

        try keychain.setString("hello", for: "greeting")
        XCTAssertEqual(try keychain.string(for: "greeting"), "hello")
    }

    func testOverwriteReplacesPreviousValue() throws {
        let keychain = makeKeychain()
        defer { try? keychain.removeAll() }

        try keychain.setString("first", for: "k")
        try keychain.setString("second", for: "k")
        XCTAssertEqual(try keychain.string(for: "k"), "second")
    }

    func testMissingKeyReturnsNil() throws {
        let keychain = makeKeychain()
        defer { try? keychain.removeAll() }

        XCTAssertNil(try keychain.string(for: "ghost"))
    }

    func testRemove() throws {
        let keychain = makeKeychain()
        defer { try? keychain.removeAll() }

        try keychain.setString("v", for: "k")
        try keychain.remove("k")
        XCTAssertNil(try keychain.string(for: "k"))
    }
}
