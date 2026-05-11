import Foundation

/// What a barcode lookup yields once we have data for the scanned product.
/// Both the on-device adapter and the (future) Worker-proxied implementation
/// converge on this value type.
struct BarcodeProduct: Equatable, Sendable {
    let barcode: String
    let name: String
    let brand: String?
    let imageURL: URL?
    let nutrition: Nutrition
    let servingGrams: Double?

    struct Nutrition: Equatable, Sendable {
        let caloriesKcalPer100g: Double
        let proteinPer100g: Double
        let carbsPer100g: Double
        let fatPer100g: Double
        let fiberPer100g: Double?
    }
}

enum BarcodeLookupError: Error, Equatable {
    case notFound
    case missingNutrition
    case network(String)
}

protocol BarcodeLookupService: Sendable {
    func lookup(barcode: String) async throws -> BarcodeProduct
}

extension BarcodeProduct {
    /// Adapts the product into the unified scan result so we can render it
    /// in the existing `ScanResultView` instead of forking the UI.
    func asScanResult(suggestedMealType: MealType) -> ScanResult {
        let grams = servingGrams ?? 100
        let scale = grams / 100.0
        return ScanResult(
            items: [
                ScanResult.DetectedItem(
                    name: name,
                    quantityGrams: grams,
                    caloriesKcal: nutrition.caloriesKcalPer100g * scale,
                    proteinGrams: nutrition.proteinPer100g * scale,
                    carbsGrams: nutrition.carbsPer100g * scale,
                    fatGrams: nutrition.fatPer100g * scale,
                    confidence: 0.99
                )
            ],
            suggestedMealType: suggestedMealType,
            confidence: 0.99,
            rawAINotes: brand.map { "Marka: \($0)" }
        )
    }
}
