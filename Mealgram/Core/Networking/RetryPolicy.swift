import Foundation

/// Exponential backoff with jitter. Default behaviour: max 3 attempts, base
/// 0.5 s, doubles each step, capped at 8 s. The Cloudflare Worker proxy
/// surfaces a `Retry-After` header on rate-limit responses — handled at the
/// client side by reading the response before sleeping.
struct RetryPolicy: Sendable {
    let maxAttempts: Int
    let baseDelay: TimeInterval
    let cap: TimeInterval

    static let `default` = RetryPolicy(maxAttempts: 3, baseDelay: 0.5, cap: 8.0)
    static let none = RetryPolicy(maxAttempts: 1, baseDelay: 0, cap: 0)

    /// Returns the delay (in seconds) to wait before the *next* attempt.
    /// Attempt is 1-indexed (the first attempt = 1).
    func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        let exponential = baseDelay * pow(2.0, Double(attempt - 1))
        let capped = min(exponential, cap)
        // Up to ±25% jitter to avoid stampedes.
        let jitter = capped * 0.25
        let lower = capped - jitter
        let upper = capped + jitter
        return Double.random(in: lower...upper)
    }
}
