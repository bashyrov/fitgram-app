import Foundation

/// Abstract over the detection pipeline so the camera flow doesn't depend
/// on Gemini directly. Real implementation lands in Milestone 1.6 against
/// the Cloudflare Worker proxy.
protocol FoodDetector: Sendable {
    func detect(from imageData: Data, suggestedMealType: MealType?) async throws -> ScanResult
}

enum DetectionError: Error, Equatable {
    case empty
    case notReady
    case transport(String)
}
