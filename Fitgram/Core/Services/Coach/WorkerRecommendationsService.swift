import Foundation
import OSLog

/// Cloudflare Worker-backed recommendations. Production path once the
/// Worker base URL + Gemini/Claude keys are wired up. The composition
/// root attaches this as `primary` to `RecommendationsService`; until
/// `baseURL` is set, the composition root passes `nil` for primary and
/// the rule-based fallback runs alone.
///
/// Endpoint contract (from spec):
///   POST {baseURL}/api/v1/user/initial-recommendations
///   Body: anonymized RecommendationsRequest (snake_case JSON)
///   Response: Recommendations JSON
///
/// Server-side prompt + Claude wiring lives in workers/ Worker source
/// — this is purely the iOS client.
final class WorkerRecommendationsService: RecommendationsServing {
    private let baseURL: URL
    private let client: any APIClient

    init(baseURL: URL, client: any APIClient) {
        self.baseURL = baseURL
        self.client = client
    }

    func generate(for request: RecommendationsRequest) async throws -> Recommendations {
        let endpoint = try Endpoint.json(
            path: "/api/v1/user/initial-recommendations",
            method: .post,
            payload: request,
            requiresAuth: false  // anonymous payload
        )
        Logger.coach.notice(
            "WorkerRecommendationsService dispatching to \(self.baseURL.absoluteString, privacy: .public)")
        return try await client.send(endpoint, expecting: Recommendations.self)
    }
}
