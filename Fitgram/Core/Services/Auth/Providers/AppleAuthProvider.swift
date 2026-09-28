import AuthenticationServices
import CryptoKit
import Foundation
import OSLog

/// Native Sign in with Apple flow. The Apple identity token (bound to a
/// one-time nonce) is exchanged for a Supabase session, so the Worker and
/// Supabase accept the same access token as for Google sign-in. Without a
/// configured Supabase project (local development) the Apple token itself is
/// kept as the session token.
@MainActor
final class AppleAuthProvider: NSObject, AuthProvider {
    let kind: AuthProviderKind = .apple

    private let supabaseExchange: SupabaseAuthExchange
    private var currentContinuation: CheckedContinuation<ASAuthorizationAppleIDCredential, any Error>?

    init(supabaseExchange: SupabaseAuthExchange = SupabaseAuthExchange()) {
        self.supabaseExchange = supabaseExchange
    }

    func signIn() async throws -> AuthCredentials {
        let rawNonce = Self.randomNonce()
        let credential = try await authorize(scopes: [.fullName, .email], hashedNonce: Self.sha256(rawNonce))
        guard let tokenData = credential.identityToken,
            let token = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidCredential
        }
        guard AppConfig.supabaseURL != nil, AppConfig.supabaseAnonKey != nil else {
            return AuthCredentials(
                userID: credential.user,
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                provider: .apple
            )
        }
        do {
            return try await supabaseExchange.exchangeAppleIDToken(token, rawNonce: rawNonce)
        } catch {
            Logger.auth.error("Apple → Supabase exchange failed: \(String(describing: error), privacy: .public)")
            throw AuthError.unknown(underlying: L("Nie udało się zalogować. Spróbuj ponownie za chwilę."))
        }
    }

    /// Asks the user to confirm with Apple once more and returns a fresh
    /// authorization code. Account deletion sends it to the Worker, which
    /// revokes the app's Apple tokens (App Store Review Guideline 5.1.1(v)).
    func authorizationCodeForAccountDeletion() async throws -> String {
        let credential = try await authorize(scopes: [], hashedNonce: nil)
        guard let data = credential.authorizationCode, let code = String(data: data, encoding: .utf8) else {
            throw AuthError.invalidCredential
        }
        return code
    }

    func signOut() async {
        // Apple doesn't expose a programmatic sign-out — the user manages
        // their app's link from Settings → Apple ID. Nothing to do locally.
    }

    private func authorize(
        scopes: [ASAuthorization.Scope],
        hashedNonce: String?
    ) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = scopes
            request.nonce = hashedNonce

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset[Int.random(in: 0..<charset.count, using: &generator)] })
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleAuthProvider: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        Task { @MainActor in
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                self.finish(with: .failure(AuthError.invalidCredential))
                return
            }
            self.finish(with: .success(credential))
        }
    }

    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: any Error
    ) {
        let mapped: AuthError
        if let asError = error as? ASAuthorizationError, asError.code == .canceled {
            mapped = .canceled
        } else {
            mapped = .unknown(underlying: error.localizedDescription)
        }
        Task { @MainActor in
            self.finish(with: .failure(mapped))
        }
    }

    private func finish(with result: Result<ASAuthorizationAppleIDCredential, any Error>) {
        currentContinuation?.resume(with: result)
        currentContinuation = nil
    }
}

extension AppleAuthProvider: ASAuthorizationControllerPresentationContextProviding {
    nonisolated func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // The system supplies the key window automatically; we provide one
        // here to satisfy the API contract. In multi-scene apps this would
        // ask the active scene — single-scene app keeps it simple.
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}
