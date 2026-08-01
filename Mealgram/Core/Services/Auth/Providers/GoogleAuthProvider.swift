import AuthenticationServices
import CryptoKit
import Foundation
import OSLog

/// Google Sign-In via OAuth 2.0 + PKCE, no Google SDK. Uses
/// `ASWebAuthenticationSession` so the system handles the Safari sheet
/// + cookie sharing with the user's logged-in Chrome / Safari sessions.
///
/// Requires `GOOGLE_OAUTH_CLIENT_ID` to be set in `Info.plist` via the
/// `Info.plist` build setting passthrough. Bundle ID must match the
/// "Bundle ID" configured on the Google Cloud OAuth client.
@MainActor
final class GoogleAuthProvider: NSObject, AuthProvider {
    let kind: AuthProviderKind = .google
    private let supabaseExchange: SupabaseAuthExchange

    /// Stored as state between `signIn()` opening the web sheet and the
    /// callback URL arriving via the system.
    private var pendingVerifier: String?

    init(supabaseExchange: SupabaseAuthExchange = SupabaseAuthExchange()) {
        self.supabaseExchange = supabaseExchange
        super.init()
    }

    func signIn() async throws -> AuthCredentials {
        guard let clientID = AppConfig.googleOAuthClientID else {
            throw AuthError.providerNotConfigured(.google)
        }
        let verifier = Self.makeCodeVerifier()
        let challenge = Self.makeCodeChallenge(from: verifier)
        self.pendingVerifier = verifier

        // Google iOS OAuth clients require redirect URIs of the reverse-
        // client-id form, e.g. "com.googleusercontent.apps.123-abc:/oauth2redirect".
        // The same URL scheme must be registered in Info.plist's
        // CFBundleURLTypes (see project.yml).
        let reverseScheme = Self.reverseClientIDScheme(from: clientID)
        let redirectURI = "\(reverseScheme):/oauth2redirect"

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account"),
        ]
        guard let authURL = components.url else {
            throw AuthError.invalidCredential
        }

        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: reverseScheme
            ) { url, error in
                if let error {
                    if let asError = error as? ASWebAuthenticationSessionError, asError.code == .canceledLogin {
                        continuation.resume(throwing: AuthError.canceled)
                    } else {
                        continuation.resume(throwing: AuthError.unknown(underlying: error.localizedDescription))
                    }
                    return
                }
                guard let url else {
                    continuation.resume(throwing: AuthError.invalidCredential)
                    return
                }
                continuation.resume(returning: url)
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            session.start()
        }

        let code = Self.parseCode(from: callbackURL)
        guard let code, let verifier = pendingVerifier else {
            throw AuthError.invalidCredential
        }
        pendingVerifier = nil
        return try await exchangeCodeForCredentials(
            code: code,
            verifier: verifier,
            clientID: clientID,
            redirectURI: "\(Self.reverseClientIDScheme(from: clientID)):/oauth2redirect"
        )
    }

    func signOut() async {}

    // MARK: - PKCE + helpers

    /// Converts `123-abc.apps.googleusercontent.com` →
    /// `com.googleusercontent.apps.123-abc` (Google's iOS OAuth scheme).
    private static func reverseClientIDScheme(from clientID: String) -> String {
        let parts = clientID.split(separator: ".").map(String.init)
        return parts.reversed().joined(separator: ".")
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func makeCodeChallenge(from verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }

    private static func parseCode(from url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == "code" })?
            .value
    }

    private func exchangeCodeForCredentials(
        code: String,
        verifier: String,
        clientID: String,
        redirectURI: String
    ) async throws -> AuthCredentials {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let body = [
            "client_id": clientID,
            "code": code,
            "code_verifier": verifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI,
        ]
        .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
        .joined(separator: "&")
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(data: data, encoding: .utf8) ?? ""
            Logger.auth.error("Google token exchange failed: \(status) \(body, privacy: .public)")
            throw AuthError.unknown(underlying: "Nie udało się dokończyć logowania Google.")
        }
        let payload = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        let userID = Self.extractSubject(fromIDToken: payload.idToken) ?? UUID().uuidString
        let expiresAt = payload.expiresIn.map { Date().addingTimeInterval(Double($0)) }
        if AppConfig.isSupabaseConfigured {
            return try await supabaseExchange.exchangeGoogleIDToken(payload.idToken)
        }
        return AuthCredentials(
            userID: userID,
            accessToken: payload.idToken,
            refreshToken: payload.refreshToken,
            expiresAt: expiresAt,
            provider: .google
        )
    }

    private static func extractSubject(fromIDToken token: String) -> String? {
        let parts = token.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
        payload = payload.replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while payload.count % 4 != 0 { payload.append("=") }
        guard let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let sub = json["sub"] as? String
        else { return nil }
        return sub
    }
}

extension GoogleAuthProvider: ASWebAuthenticationPresentationContextProviding {
    nonisolated func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        MainActor.assumeIsolated {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
        }
    }
}

private struct GoogleTokenResponse: Decodable {
    let accessToken: String
    let idToken: String
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case idToken = "id_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

extension Data {
    fileprivate func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
