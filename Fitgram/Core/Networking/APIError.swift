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
            return L("Server not configured. Try updating the app.")
        case .transport, .http(503, _), .http(504, _):
            return L("Brak połączenia. Sprawdź internet i spróbuj jeszcze raz.")
        case .http(429, _) where isFreeTierQuota:
            return TL(
                pl: "Tygodniowy limit AI wykorzystany. Wróci w poniedziałek albo bez limitu w Pro.",
                en: "Weekly AI limit used up. It resets on Monday, or go unlimited with Pro.",
                uk: "Тижневий ліміт AI вичерпано. Оновиться в понеділок, або без ліміту в Pro.",
                ru: "Недельный лимит ИИ исчерпан. Обновится в понедельник, или без лимита в Pro.",
                es: "Límite semanal de AI agotado. Se renueva el lunes, o sin límite con Pro."
            )
        case .http(429, _):
            return L("AI odpocznie do jutra. Dzienny limit bezpieczeństwa został wykorzystany.")
        case .http(502, _):
            return L("AI chwilowo nie odpowiada. Możesz dodać posiłek ręcznie.")
        case .unauthorized:
            return L("Sesja wygasła. Zaloguj się ponownie.")
        case .http, .decoding, .unknown:
            return L("Something went wrong. Try again in a moment.")
        }
    }
}

extension APIError {
    /// The Worker refused because the free weekly AI pool is empty
    /// (`429` with `"reason": "free_tier"`), not the hidden safety cap.
    var isFreeTierQuota: Bool {
        guard case .http(429, let body) = self, let body,
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
        else { return false }
        return object["reason"] as? String == "free_tier"
    }
}
