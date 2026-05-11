import Foundation
import OSLog

/// Façade in front of the per-provider implementations. Responsible for:
/// 1. Routing UI-initiated sign-in to the correct provider.
/// 2. Persisting tokens through `TokenStore`.
/// 3. Updating the `AuthSession` observable so SwiftUI reroutes.
///
/// Provider-specific quirks stay inside each `AuthProvider`. This type does
/// nothing provider-specific.
@MainActor
final class AuthService {
    private let providers: [AuthProviderKind: any AuthProvider]
    private let tokenStore: TokenStore
    private let session: AuthSession

    init(
        providers: [any AuthProvider],
        tokenStore: TokenStore = TokenStore(),
        session: AuthSession
    ) {
        self.providers = Dictionary(uniqueKeysWithValues: providers.map { ($0.kind, $0) })
        self.tokenStore = tokenStore
        self.session = session
    }

    /// Reads token store on launch to decide whether we already have a session.
    /// In a real build we'd validate the JWT with Supabase here — for now we
    /// trust the keychain.
    func restoreSession() async {
        do {
            guard let userID = try tokenStore.userID,
                try tokenStore.accessToken != nil,
                let providerRaw = try tokenStore.providerKind,
                let provider = AuthProviderKind(rawValue: providerRaw)
            else {
                session.update(phase: .anonymous)
                return
            }
            let user = AuthUser(id: userID, email: nil, displayName: nil, provider: provider)
            session.update(phase: .authenticated(user))
        } catch {
            Logger.auth.error("Restore session failed: \(String(describing: error))")
            session.update(phase: .anonymous)
        }
    }

    func signIn(with kind: AuthProviderKind) async {
        guard let provider = providers[kind] else {
            session.surface(error: .providerNotConfigured(kind))
            return
        }

        session.setWorking(true)
        defer { session.setWorking(false) }

        do {
            let credentials = try await provider.signIn()
            try tokenStore.save(session: credentials)
            let user = AuthUser(
                id: credentials.userID,
                email: nil,
                displayName: nil,
                provider: credentials.provider
            )
            session.update(phase: .authenticated(user))
            Logger.auth.info("Signed in via \(kind.rawValue, privacy: .public)")
        } catch let error as AuthError {
            Logger.auth.error("Sign-in failed (\(kind.rawValue, privacy: .public)): \(error.userMessage)")
            session.surface(error: error)
        } catch {
            Logger.auth.error("Sign-in failed (\(kind.rawValue, privacy: .public)): \(String(describing: error))")
            session.surface(error: .unknown(underlying: String(describing: error)))
        }
    }

    func signOut() async {
        session.setWorking(true)
        defer { session.setWorking(false) }

        if case .authenticated(let user) = session.phase, let provider = providers[user.provider] {
            await provider.signOut()
        }
        do {
            try tokenStore.clear()
        } catch {
            Logger.auth.error("Token clear on sign-out failed: \(String(describing: error))")
        }
        session.update(phase: .anonymous)
    }
}
