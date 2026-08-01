import Foundation

struct TimeZoneInterceptor: RequestInterceptor {
    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        var adapted = request
        let timeZone = TimeZone.current
        adapted.setValue(timeZone.identifier, forHTTPHeaderField: "X-Mealgram-Time-Zone")
        adapted.setValue(
            String(timeZone.secondsFromGMT() / 60),
            forHTTPHeaderField: "X-Mealgram-Time-Zone-Offset-Minutes"
        )
        return adapted
    }
}
