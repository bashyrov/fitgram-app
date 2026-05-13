import Foundation
import OSLog

protocol RecommendationsServing: Sendable {
    /// Returns a recommendations bundle for the given (anonymous)
    /// profile. Implementations decide whether to call out to the
    /// network — callers don't care.
    func generate(for request: RecommendationsRequest) async throws -> Recommendations
}

/// Composite service that tries the live Worker first and falls back to
/// the deterministic rule-based generator on any failure. This is the
/// instance composition root hands to the rest of the app — switching
/// behaviour later means changing the constructor, not every call site.
final class RecommendationsService: RecommendationsServing {
    private let primary: (any RecommendationsServing)?
    private let fallback: any RecommendationsServing

    init(
        primary: (any RecommendationsServing)? = nil,
        fallback: any RecommendationsServing = RuleBasedRecommendationsService()
    ) {
        self.primary = primary
        self.fallback = fallback
    }

    func generate(for request: RecommendationsRequest) async throws -> Recommendations {
        guard let primary else {
            return try await fallback.generate(for: request)
        }
        do {
            return try await primary.generate(for: request)
        } catch {
            Logger.coach.notice(
                "RecommendationsService primary failed, falling back: \(String(describing: error))"
            )
            return try await fallback.generate(for: request)
        }
    }
}

