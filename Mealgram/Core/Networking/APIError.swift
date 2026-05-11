import Foundation

enum APIError: Error, Equatable {
    /// `AppConfig.workerBaseURL` is missing — the Cloudflare Worker hasn't
    /// been wired up yet.
    case notConfigured

    /// `URLError` from URLSession (offline, timeout, DNS).
    case transport(URLError.Code)

    /// HTTP non-2xx response. `body` is the raw bytes so callers can show or
    /// decode them if they want (e.g. validation error JSON).
    case http(status: Int, body: Data?)

    /// JSON couldn't be decoded into the requested model.
    case decoding(reason: String)

    /// Token store doesn't have a JWT but the endpoint required one.
    case unauthorized

    /// Anything we didn't anticipate.
    case unknown(reason: String)
}

extension APIError {
    /// True for transient errors worth retrying (network blips + 5xx).
    var isRetryable: Bool {
        switch self {
        case .transport(let code):
            return code == .timedOut
                || code == .networkConnectionLost
                || code == .notConnectedToInternet
                || code == .dnsLookupFailed
                || code == .resourceUnavailable
        case .http(let status, _):
            return status >= 500 && status < 600
        case .notConfigured, .decoding, .unauthorized, .unknown:
            return false
        }
    }

    var userMessage: String {
        switch self {
        case .notConfigured:
            return String(localized: "Brak konfiguracji serwera. Spróbuj zaktualizować aplikację.")
        case .transport, .http(503, _), .http(504, _):
            return String(localized: "Brak połączenia. Sprawdź internet i spróbuj jeszcze raz.")
        case .unauthorized:
            return String(localized: "Sesja wygasła. Zaloguj się ponownie.")
        case .http, .decoding, .unknown:
            return String(localized: "Coś poszło nie tak. Spróbuj ponownie za chwilę.")
        }
    }
}
