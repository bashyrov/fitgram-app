import Foundation
import SwiftData

/// User-saved meal template — snapshot of "what I ate" that can be
/// re-added with one tap. Decoupled from `Food` (catalog) because
/// favourites come from every entry path: photo scans, barcodes, voice,
/// quick database, manual entry. The snapshot stores absolute values
/// for the saved portion so re-add is deterministic — no live join.
@Model
final class FavoriteMeal {
    var id: UUID = UUID()
    var userRemoteID: String = ""
    var name: String = ""
    /// Default portion in grams this favourite re-adds at. Editable
    /// before save when the user taps to re-add.
    var defaultQuantityGrams: Double = 0
    var caloriesKcal: Double = 0
    var proteinGrams: Double = 0
    var carbsGrams: Double = 0
    var fatGrams: Double = 0
    var fiberGrams: Double?

    /// Where the favourite was first captured — drives a small chip
    /// icon in the carousel ("📦 Open Food Facts", "📸 ze skanu", etc.).
    var sourceHintRaw: String = ""
    /// Optional catalog backlink. Set when the favourite was created
    /// from a Quick DB row; nil for manual / scan / barcode origins.
    var catalogFoodID: UUID?

    var useCount: Int = 0
    var lastUsedAt: Date?
    var createdAt: Date = Date()
    init(
        id: UUID = UUID(),
        userRemoteID: String,
        name: String,
        defaultQuantityGrams: Double,
        caloriesKcal: Double,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double? = nil,
        source: MealSource = .manual,
        catalogFoodID: UUID? = nil
    ) {
        self.id = id
        self.userRemoteID = userRemoteID
        self.name = name
        self.defaultQuantityGrams = defaultQuantityGrams
        self.caloriesKcal = caloriesKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sourceHintRaw = source.rawValue
        self.catalogFoodID = catalogFoodID
        self.useCount = 0
        self.lastUsedAt = nil
        self.createdAt = Date()
    }
}

extension FavoriteMeal {
    var sourceHint: MealSource {
        get { MealSource(rawValue: sourceHintRaw) ?? .manual }
        set { sourceHintRaw = newValue.rawValue }
    }

    /// Materialise into a fresh `FoodItem` at the requested portion.
    /// Scales every macro by `quantityGrams / defaultQuantityGrams`
    /// so re-adding at a different portion stays consistent.
    func foodItem(quantityGrams: Double? = nil) -> FoodItem {
        let portion = quantityGrams ?? defaultQuantityGrams
        let factor = defaultQuantityGrams > 0 ? portion / defaultQuantityGrams : 1
        return FoodItem(
            name: name,
            quantityGrams: portion,
            caloriesKcal: caloriesKcal * factor,
            proteinGrams: proteinGrams * factor,
            carbsGrams: carbsGrams * factor,
            fatGrams: fatGrams * factor,
            fiberGrams: fiberGrams.map { $0 * factor },
            catalogFoodID: catalogFoodID
        )
    }
}
