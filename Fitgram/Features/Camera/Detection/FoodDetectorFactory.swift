import Foundation
import OSLog

/// Picks the right detector at run time:
/// - if `AppConfig.workerBaseURL` is set (production / staging build),
///   use `WorkerFoodDetector` with an authenticated APIClient.
/// - otherwise (developer build with no Worker yet), fall back to
///   `MockFoodDetector` so the camera flow stays exercisable.
enum FoodDetectorFactory {
    static func make(
        tokenStore: TokenStore = TokenStore(),
        session: URLSession = .shared
    ) -> any FoodDetector {
        guard let workerURL = AppConfig.workerBaseURL else {
            #if DEBUG
            Logger.networking.notice("WORKER_BASE_URL absent — using MockFoodDetector")
            return MockFoodDetector()
            #else
            Logger.networking.error("WORKER_BASE_URL absent — photo AI is not configured")
            return UnconfiguredFoodDetector()
            #endif
        }
        let client = URLSessionAPIClient(
            session: session,
            baseURL: workerURL,
            interceptors: [AuthInterceptor(tokenStore: tokenStore), TimeZoneInterceptor(), LoggingInterceptor()],
            retryPolicy: .default
        )
        return WorkerFoodDetector(client: client)
    }
}
