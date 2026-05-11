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
            return String(localized: "Logowanie przez \(kind.displayName) nie jest jeszcze dostępne.")
        case .canceled:
            return String(localized: "Logowanie zostało anulowane.")
        case .invalidCredential:
            return String(localized: "Nie udało się potwierdzić Twoich danych. Spróbuj jeszcze raz.")
        case .network:
            return String(localized: "Brak połączenia. Sprawdź internet i spróbuj ponownie.")
        case .unknown:
            return String(localized: "Coś poszło nie tak. Spróbuj ponownie za chwilę.")
        }
    }
}
