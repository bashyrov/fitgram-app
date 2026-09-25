import Foundation
import OSLog

/// Lightweight debug logger — emits method + path + status. Active only in
/// DEBUG builds so release binaries don't ship verbose log lines.
struct LoggingInterceptor: RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        #if DEBUG
        let method = request.httpMethod ?? "?"
        let path = request.url?.path(percentEncoded: false) ?? "?"
        Logger.networking.debug("→ \(method, privacy: .public) \(path, privacy: .public)")
        #endif
        return request
    }
}
