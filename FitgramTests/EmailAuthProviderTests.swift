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
            XCTFail("Expected weakPassword")
        } catch {
            XCTAssertEqual(error as? EmailAuthError, .weakPassword)
        }
    }

    func testPasswordRequirements() {
        XCTAssertTrue(EmailAuthProvider.meetsRequirements("Fitgram2026"))
        XCTAssertFalse(EmailAuthProvider.meetsRequirements("Fitgr4m"), "7 characters")
        XCTAssertFalse(EmailAuthProvider.meetsRequirements("fitgram2026"), "no uppercase")
        XCTAssertFalse(EmailAuthProvider.meetsRequirements("FITGRAM2026"), "no lowercase")
        XCTAssertFalse(EmailAuthProvider.meetsRequirements("Fitgramowo"), "no digit")
        XCTAssertFalse(EmailAuthProvider.meetsRequirements("ŁÓŹŻ1234a"), "Polish capitals do not count as uppercase")
    }

    func testNewAccountsNeedStrongPassword() async {
        XCTAssertEqual(EmailAuthProvider.minimumPasswordLength, 8)
        let provider = EmailAuthProvider()
        do {
            _ = try await provider.signIn(email: "anna@fitgram.space", password: "fitgram2026", createAccount: true)
            XCTFail("Expected weakPassword")
        } catch {
            XCTAssertEqual(error as? EmailAuthError, .weakPassword)
        }
        do {
            _ = try await provider.signIn(email: "anna@fitgram.space", password: "", createAccount: false)
            XCTFail("Expected weakPassword")
        } catch {
            XCTAssertEqual(error as? EmailAuthError, .weakPassword)
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
            .weakPassword
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
            .invalidEmail, .weakPassword, .invalidCredentials, .accountExists,
            .confirmationRequired, .rateLimited, .network, .notConfigured, .unknown,
        ]
        for error in all {
            XCTAssertFalse((error.errorDescription ?? "").isEmpty, "\(error)")
        }
    }
}
