import Foundation

@testable import Mealgram

/// Test double for the `AuthProvider` protocol — lets us drive `AuthService`
/// without touching real Apple/Google/Supabase APIs.
final class MockAuthProvider: AuthProvider, @unchecked Sendable {
    let kind: AuthProviderKind
    var result: Result<AuthCredentials, any Error>
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0

    init(kind: AuthProviderKind, result: Result<AuthCredentials, any Error>) {
        self.kind = kind
        self.result = result
    }

    func signIn() async throws -> AuthCredentials {
        signInCallCount += 1
        return try result.get()
    }

    func signOut() async {
        signOutCallCount += 1
    }
}

extension AuthCredentials {
    static func fixture(
        userID: String = "user-1",
        provider: AuthProviderKind = .apple
    ) -> AuthCredentials {
        AuthCredentials(
            userID: userID,
            accessToken: "access-token-\(userID)",
            refreshToken: "refresh-token-\(userID)",
            expiresAt: nil,
            provider: provider
        )
    }
}
