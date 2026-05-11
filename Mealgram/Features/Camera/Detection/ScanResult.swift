import Foundation

/// What the AI (or mock detector) hands back after processing a photo.
/// Stays decoupled from `MealEntry` so detectors don't need to know about
/// SwiftData; the result is converted into models at save time.
struct ScanResult: Sendable, Equatable {
    var items: [DetectedItem]
    var suggestedMealType: MealType
    var confidence: Double
    var rawAINotes: String?

    struct DetectedItem: Sendable, Equatable, Identifiable {
        var id = UUID()
        var name: String
        var quantityGrams: Double
        var caloriesKcal: Double
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var confidence: Double
    }
}

extension ScanResult {
    var totalCalories: Double {
        items.reduce(0) { $0 + $1.caloriesKcal }
    }
    var totalProtein: Double {
        items.reduce(0) { $0 + $1.proteinGrams }
    }
    var totalCarbs: Double {
        items.reduce(0) { $0 + $1.carbsGrams }
    }
    var totalFat: Double {
        items.reduce(0) { $0 + $1.fatGrams }
    }
}
