import XCTest

@testable import Fitgram

@MainActor
final class EmailAuthProviderTests: XCTestCase {
    func testEmailValidation() {
        XCTAssertTrue(EmailAuthProvider.isPlausibleEmail("anna@fitgram.space"))
        XCTAssertFalse(EmailAuthProvider.isPlausibleEmail("anna"))
        XCTAssertFalse(EmailAuthProvider.isPlausibleEmail("anna@localhost"))
        XCTAssertFalse(EmailAuthProvider.isPlausibleEmail("@fitgram.space"))
        XCTAssertFalse(EmailAuthProvider.isPlausibleEmail("an na@fitgram.space"))
    }

    func testRejectsInvalidInputBeforeCallingSupabase() async {
        let provider = EmailAuthProvider()
        do {
            _ = try await provider.signIn(email: "not-an-email", password: "secret123", createAccount: false)
            XCTFail("Expected invalidEmail")
        } catch {
            XCTAssertEqual(error as? EmailAuthError, .invalidEmail)
        }
        do {
            _ = try await provider.signIn(email: "anna@fitgram.space", password: "123", createAccount: true)
            XCTFail("Expected passwordTooShort")
        } catch {
            XCTAssertEqual(error as? EmailAuthError, .passwordTooShort)
        }
    }

    func testMapsSupabaseErrors() {
        typealias Exchange = SupabaseAuthExchange.ExchangeError
        XCTAssertEqual(
            EmailAuthProvider.map(
                Exchange.http(status: 400, body: #"{"error_code":"invalid_credentials"}"#), createAccount: false),
            .invalidCredentials
        )
        XCTAssertEqual(
            EmailAuthProvider.map(
                Exchange.http(status: 422, body: #"{"msg":"User already registered"}"#), createAccount: true),
            .accountExists
        )
        XCTAssertEqual(
            EmailAuthProvider.map(
                Exchange.http(status: 422, body: #"{"error_code":"weak_password"}"#), createAccount: true),
            .passwordTooShort
        )
        XCTAssertEqual(
            EmailAuthProvider.map(Exchange.http(status: 429, body: ""), createAccount: true),
            .rateLimited
        )
        XCTAssertEqual(
            EmailAuthProvider.map(Exchange.emailConfirmationRequired, createAccount: true), .confirmationRequired)
        XCTAssertEqual(EmailAuthProvider.map(Exchange.notConfigured, createAccount: false), .notConfigured)
    }

    func testEveryErrorHasAMessage() {
        let all: [EmailAuthError] = [
            .invalidEmail, .passwordTooShort, .invalidCredentials, .accountExists,
            .confirmationRequired, .rateLimited, .network, .notConfigured, .unknown,
        ]
        for error in all {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty, "\(error)")
        }
    }
}
