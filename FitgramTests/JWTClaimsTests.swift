import XCTest

@testable import Fitgram

final class JWTClaimsTests: XCTestCase {
    private func token(_ claims: String) -> String {
        let payload = Data(claims.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return "eyJhbGciOiJIUzI1NiJ9.\(payload).signature"
    }

    func testReadsEmailFromSupabaseAccessToken() {
        let jwt = token(#"{"sub":"abc","email":"x7k2@privaterelay.appleid.com","role":"authenticated"}"#)
        XCTAssertEqual(JWTClaims.email(in: jwt), "x7k2@privaterelay.appleid.com")
    }

    func testMissingOrEmptyEmailIsNil() {
        XCTAssertNil(JWTClaims.email(in: token(#"{"sub":"abc"}"#)))
        XCTAssertNil(JWTClaims.email(in: token(#"{"sub":"abc","email":""}"#)))
        XCTAssertNil(JWTClaims.email(in: "not-a-jwt"))
    }
}
