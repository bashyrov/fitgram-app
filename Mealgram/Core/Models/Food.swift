import Foundation
import SwiftData

/// Catalog entry — one row per canonical food, dish, or product. Restaurant
/// items, Polish home recipes, and packaged products all live in the same
/// table; `category` + optional `brand` / `restaurantName` disambiguate.
///
/// Nutritional values are stored per 100g; portion-time math happens in
/// `FoodItem`, never here.
@Model
final class Food {
    var id: UUID = UUID()
    var remoteID: String?

    /// Default Polish name; the localizations payload (JSON-encoded) carries
    /// other languages. Storing JSON for now keeps the schema simple — we
    /// move to a dedicated relationship if querying by other locales is ever
    /// needed.
    var name: String = ""
    var localizationsJSON: String?
    var brand: String?
    var restaurantName: String?

    var categoryRaw: String = ""
    var caloriesKcalPer100g: Double = 0
    var proteinGramsPer100g: Double = 0
    var carbsGramsPer100g: Double = 0
    var fatGramsPer100g: Double = 0
    var fiberGramsPer100g: Double?

    var defaultPortionGrams: Double?
    var barcode: String?
    var imageURLString: String?
    var verified: Bool = false
    var createdAt: Date = Date()
    /// How many times the local user has picked this row from Quick DB.
    /// Drives the "Częste" carousel — defaults to 0 for newly-seeded rows
    /// and lightweight-migrates cleanly because SwiftData fills new
    /// non-optional `Int` columns with their default.
    var pickCount: Int = 0
    /// Most recent pick. Nil until the user has touched the row at least
    /// once.
    var lastPickedAt: Date?

    init(
        id: UUID = UUID(),
        remoteID: String? = nil,
        name: String,
        brand: String? = nil,
        restaurantName: String? = nil,
        category: FoodCategory = .general,
        caloriesKcalPer100g: Double,
        proteinGramsPer100g: Double = 0,
        carbsGramsPer100g: Double = 0,
        fatGramsPer100g: Double = 0,
        fiberGramsPer100g: Double? = nil,
        defaultPortionGrams: Double? = nil,
        barcode: String? = nil,
        imageURL: URL? = nil,
        verified: Bool = false
    ) {
        self.id = id
        self.remoteID = remoteID
        self.name = name
        self.brand = brand
        self.restaurantName = restaurantName
        self.categoryRaw = category.rawValue
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
        self.fiberGramsPer100g = fiberGramsPer100g
        self.defaultPortionGrams = defaultPortionGrams
        self.barcode = barcode
        self.imageURLString = imageURL?.absoluteString
        self.verified = verified
        self.createdAt = Date()
    }
}

extension Food {
    var category: FoodCategory {
        get { FoodCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    var imageURL: URL? {
        get { imageURLString.flatMap(URL.init(string:)) }
        set { imageURLString = newValue?.absoluteString }
    }
}
