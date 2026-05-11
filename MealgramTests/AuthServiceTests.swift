import XCTest

@testable import Mealgram

@MainActor
final class AuthServiceTests: XCTestCase {
    private var keychain: Keychain!
    private var tokenStore: TokenStore!
    private var session: AuthSession!

    override func setUp() async throws {
        keychain = Keychain(service: "app.mealgram.tests.authservice")
        try? keychain.removeAll()
        tokenStore = TokenStore(keychain: keychain)
        session = AuthSession()
    }

    override func tearDown() async throws {
        try? keychain.removeAll()
    }

    func testSuccessfulSignInPersistsTokensAndUpdatesSession() async throws {
        let credentials = AuthCredentials.fixture(userID: "u-success", provider: .apple)
        let provider = MockAuthProvider(kind: .apple, result: .success(credentials))
        let service = AuthService(providers: [provider], tokenStore: tokenStore, session: session)

        await service.signIn(with: .apple)

        XCTAssertEqual(provider.signInCallCount, 1)
        switch session.phase {
        case .authenticated(let user):
            XCTAssertEqual(user.id, "u-success")
            XCTAssertEqual(user.provider, .apple)
        default:
            XCTFail("Expected authenticated phase, got \(session.phase)")
        }
        XCTAssertEqual(try tokenStore.userID, "u-success")
        XCTAssertEqual(try tokenStore.accessToken, credentials.accessToken)
        XCTAssertNil(session.lastError)
    }

    func testProviderNotConfiguredSurfacesError() async throws {
        // No providers registered → asking for Google should surface
        // .providerNotConfigured without touching the keychain.
        let service = AuthService(providers: [], tokenStore: tokenStore, session: session)

        await service.signIn(with: .google)

        XCTAssertEqual(session.lastError, .providerNotConfigured(.google))
        XCTAssertEqual(session.phase, .unknown)
        XCTAssertNil(try tokenStore.accessToken)
    }

    func testProviderFailurePreservesAnonymousSession() async throws {
        let failing = MockAuthProvider(kind: .email, result: .failure(AuthError.invalidCredential))
        let service = AuthService(providers: [failing], tokenStore: tokenStore, session: session)

        await service.signIn(with: .email)

        XCTAssertEqual(session.lastError, .invalidCredential)
        XCTAssertEqual(failing.signInCallCount, 1)
        XCTAssertNil(try tokenStore.accessToken)
    }

    func testSignOutClearsTokensAndResetsSession() async throws {
        let credentials = AuthCredentials.fixture(userID: "u-bye", provider: .apple)
        let provider = MockAuthProvider(kind: .apple, result: .success(credentials))
        let service = AuthService(providers: [provider], tokenStore: tokenStore, session: session)
        await service.signIn(with: .apple)

        await service.signOut()

        XCTAssertEqual(session.phase, .anonymous)
        XCTAssertEqual(provider.signOutCallCount, 1)
        XCTAssertNil(try tokenStore.accessToken)
    }

    func testRestoreSessionFromPersistedTokens() async throws {
        let credentials = AuthCredentials.fixture(userID: "u-back", provider: .google)
        try tokenStore.save(session: credentials)

        let provider = MockAuthProvider(kind: .google, result: .success(credentials))
        let service = AuthService(providers: [provider], tokenStore: tokenStore, session: session)

        await service.restoreSession()

        switch session.phase {
        case .authenticated(let user):
            XCTAssertEqual(user.id, "u-back")
            XCTAssertEqual(user.provider, .google)
        default:
            XCTFail("Expected restored authenticated phase, got \(session.phase)")
        }
    }

    func testRestoreSessionWithEmptyStoreBecomesAnonymous() async throws {
        let service = AuthService(providers: [], tokenStore: tokenStore, session: session)

        await service.restoreSession()

        XCTAssertEqual(session.phase, .anonymous)
    }
}
