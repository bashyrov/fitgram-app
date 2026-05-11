import AuthenticationServices
import Foundation
import OSLog

/// Native Sign in with Apple flow. In production, the `identityToken` is
/// posted to our Supabase Edge Function which validates with Apple, mints a
/// Supabase JWT, and returns it — for now (no Supabase wired yet) we treat
/// the identity token itself as the access token and the Apple user ID as
/// the local user ID. Swap in the real exchange in Milestone 1.6.
@MainActor
final class AppleAuthProvider: NSObject, AuthProvider {
    let kind: AuthProviderKind = .apple

    private var currentContinuation: CheckedContinuation<AuthCredentials, Error>?

    func signIn() async throws -> AuthCredentials {
        try await withCheckedThrowingContinuation { continuation in
            self.currentContinuation = continuation

            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }
    }

    func signOut() async {
        // Apple doesn't expose a programmatic sign-out — the user manages
        // their app's link from Settings → Apple ID. Nothing to do locally.
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
            guard let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8)
            else {
                self.finish(with: .failure(AuthError.invalidCredential))
                return
            }

            let credentials = AuthCredentials(
                userID: credential.user,
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                provider: .apple
            )
            self.finish(with: .success(credentials))
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

    private func finish(with result: Result<AuthCredentials, any Error>) {
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
