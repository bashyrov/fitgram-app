import Foundation

/// Persists the authenticated session's tokens + user identifier in the
/// keychain. One source of truth — feature code goes through this rather
/// than calling `Keychain` directly so the schema stays in one place.
struct TokenStore: Sendable {
    private enum Account {
        static let accessToken = "auth.accessToken"
        static let refreshToken = "auth.refreshToken"
        static let userID = "auth.userID"
        static let providerKind = "auth.providerKind"
    }

    private let keychain: Keychain

    init(keychain: Keychain = Keychain()) {
        self.keychain = keychain
    }

    var accessToken: String? {
        get throws { try keychain.string(for: Account.accessToken) }
    }

    var refreshToken: String? {
        get throws { try keychain.string(for: Account.refreshToken) }
    }

    var userID: String? {
        get throws { try keychain.string(for: Account.userID) }
    }

    var providerKind: String? {
        get throws { try keychain.string(for: Account.providerKind) }
    }

    func save(session: AuthCredentials) throws {
        try keychain.setString(session.accessToken, for: Account.accessToken)
        if let refresh = session.refreshToken {
            try keychain.setString(refresh, for: Account.refreshToken)
        } else {
            try keychain.remove(Account.refreshToken)
        }
        try keychain.setString(session.userID, for: Account.userID)
        try keychain.setString(session.provider.rawValue, for: Account.providerKind)
    }

    func clear() throws {
        try keychain.remove(Account.accessToken)
        try keychain.remove(Account.refreshToken)
        try keychain.remove(Account.userID)
        try keychain.remove(Account.providerKind)
    }
}
