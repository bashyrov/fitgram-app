import Foundation
import OSLog
import Security

/// Thin wrapper around Keychain Services for storing small secret blobs
/// (auth tokens, refresh tokens, the current user identifier). Generic
/// password class, accessible only after the device has been unlocked once.
///
/// Errors are localized internally because they're a developer concern, not
/// a user-facing one — but they're surfaced via the throwing API so call
/// sites can react (e.g. force re-auth on read failure).
struct Keychain: Sendable {
    enum Failure: Error, Equatable {
        case unexpectedStatus(OSStatus)
        case dataCorruption
    }

    let service: String

    init(service: String = AppConfig.bundleIdentifier) {
        self.service = service
    }

    func set(_ value: Data, for account: String) throws {
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributesToSet: [String: Any] = [
            kSecValueData as String: value,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToSet as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var addQuery = baseQuery
            addQuery.merge(attributesToSet) { $1 }
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Logger.keychain.error("Keychain add failed for account=\(account) status=\(addStatus)")
                throw Failure.unexpectedStatus(addStatus)
            }
        default:
            Logger.keychain.error("Keychain update failed for account=\(account) status=\(updateStatus)")
            throw Failure.unexpectedStatus(updateStatus)
        }
    }

    func data(for account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { throw Failure.dataCorruption }
            return data
        case errSecItemNotFound:
            return nil
        default:
            Logger.keychain.error("Keychain read failed for account=\(account) status=\(status)")
            throw Failure.unexpectedStatus(status)
        }
    }

    func remove(_ account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.keychain.error("Keychain remove failed for account=\(account) status=\(status)")
            throw Failure.unexpectedStatus(status)
        }
    }

    func removeAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            Logger.keychain.error("Keychain removeAll failed status=\(status)")
            throw Failure.unexpectedStatus(status)
        }
    }
}

extension Keychain {
    func setString(_ string: String, for account: String) throws {
        guard let data = string.data(using: .utf8) else { throw Failure.dataCorruption }
        try set(data, for: account)
    }

    func string(for account: String) throws -> String? {
        guard let data = try data(for: account) else { return nil }
        guard let string = String(data: data, encoding: .utf8) else { throw Failure.dataCorruption }
        return string
    }
}
