import XCTest

@testable import Fitgram

final class AccessTokenProviderTests: XCTestCase {
    private func jwt(exp: Date) -> String {
        let payload = #"{"sub":"u-1","exp":\#(Int(exp.timeIntervalSince1970))}"#
        let encoded = Data(payload.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(encoded).signature"
    }

    func testReadsExpiryFromJWT() throws {
        let exp = Date(timeIntervalSince1970: 1_900_000_000)
        XCTAssertEqual(AccessTokenProvider.expiry(ofJWT: jwt(exp: exp)), exp)
        XCTAssertNil(AccessTokenProvider.expiry(ofJWT: "not-a-jwt"))
    }

    func testReturnsStoredTokenWhileFresh() async throws {
        let keychain = Keychain(service: "app.fitgram.tests.tokens.fresh")
        defer { try? keychain.removeAll() }
        let store = TokenStore(keychain: keychain)
        let token = jwt(exp: Date().addingTimeInterval(3600))
        try store.save(
            session: AuthCredentials(
                userID: "u-1", accessToken: token, refreshToken: "r-1", expiresAt: nil, provider: .email))
        let provider = AccessTokenProvider(tokenStore: store)
        let value = try await provider.validAccessToken()
        XCTAssertEqual(value, token)
    }

    func testExpiredTokenWithoutRefreshTokenIsSignedOut() async throws {
        let keychain = Keychain(service: "app.fitgram.tests.tokens.expired")
        defer { try? keychain.removeAll() }
        let store = TokenStore(keychain: keychain)
        try store.save(
            session: AuthCredentials(
                userID: "u-1", accessToken: jwt(exp: Date().addingTimeInterval(-60)), refreshToken: nil,
                expiresAt: nil, provider: .email))
        let provider = AccessTokenProvider(tokenStore: store)
        do {
            _ = try await provider.validAccessToken()
            XCTFail("Expected signedOut")
        } catch AccessTokenProvider.ProviderError.signedOut {
            // expected
        }
    }
}
