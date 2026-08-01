import Foundation

/// Returns a canned response so the entire scan → results → save loop can
/// be exercised in the simulator without a real AI call. Real Gemini-2.5
/// detector replaces this in Milestone 1.6.
struct MockFoodDetector: FoodDetector {
    var latency: Duration = .milliseconds(800)
    var fixture: ScanResult

    init(latency: Duration = .milliseconds(800), fixture: ScanResult = .defaultFixture) {
        self.latency = latency
        self.fixture = fixture
    }

    func detect(from imageData: Data, suggestedMealType: MealType?) async throws -> ScanResult {
        if !imageData.isEmpty {
            try? await Task.sleep(for: latency)
        }
        if let suggestedMealType {
            var result = fixture
            result.suggestedMealType = suggestedMealType
            return result
        }
        return fixture
    }
}

extension ScanResult {
    /// Canonical "Polish home plate" used for dev + tests.
    static var defaultFixture: ScanResult {
        ScanResult(
            items: [
                DetectedItem(
                    name: "Kotlet schabowy",
                    quantityGrams: 180,
                    caloriesKcal: 420,
                    proteinGrams: 32,
                    carbsGrams: 18,
                    fatGrams: 22,
                    confidence: 0.92
                ),
                DetectedItem(
                    name: "Ziemniaki gotowane",
                    quantityGrams: 200,
                    caloriesKcal: 160,
                    proteinGrams: 4,
                    carbsGrams: 36,
                    fatGrams: 0.3,
                    confidence: 0.95
                ),
                DetectedItem(
                    name: "Surówka z kapusty",
                    quantityGrams: 120,
                    caloriesKcal: 60,
                    proteinGrams: 1.4,
                    carbsGrams: 8,
                    fatGrams: 3,
                    confidence: 0.81
                ),
            ],
            suggestedMealType: .lunch,
            confidence: 0.89,
            rawAINotes: "Safe example of a home dish."
        )
    }
}
