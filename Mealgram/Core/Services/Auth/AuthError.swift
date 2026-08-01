import Foundation

enum AuthError: Error, Equatable {
    /// Provider hasn't been wired up yet (missing credentials in `AppConfig`).
    case providerNotConfigured(AuthProviderKind)
    /// User dismissed the system auth sheet without finishing.
    case canceled
    /// Provider returned a token but it failed validation server-side.
    case invalidCredential
    /// Network failure during the auth handshake.
    case network(underlying: String)
    /// Anything else.
    case unknown(underlying: String)
}

extension AuthError {
    /// Localized message safe to show in UI.
    var userMessage: String {
        switch self {
        case .providerNotConfigured(let kind):
            return String.localizedStringWithFormat(L("Sign-in via %@ is not yet available."), kind.displayName)
        case .canceled:
            return L("Logowanie zostało anulowane.")
        case .invalidCredential:
            return L("Nie udało się potwierdzić Twoich danych. Spróbuj jeszcze raz.")
        case .network:
            return L("No connection. Check the internet and try again.")
        case .unknown:
            return L("Something went wrong. Try again in a moment.")
        }
    }
}
