import Foundation

struct UnconfiguredFoodDetector: FoodDetector {
    func detect(from imageData: Data, suggestedMealType: MealType?) async throws -> ScanResult {
        throw APIError.notConfigured
    }
}
