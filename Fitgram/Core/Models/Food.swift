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
    /// Drives the "Frequent" carousel — defaults to 0 for newly-seeded rows
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

    /// User-visible name. Reads `localizationsJSON` for a translation matching
    /// the current locale's language code; falls back to `name` (canonical
    /// English) when there's no match. Custom user-created rows have no JSON
    /// payload so they pass through unchanged.
    var localizedName: String {
        guard let map = localizationsMap else { return name }
        let code = LocalizationStore.currentLanguageCode()
        if let localized = map[code], !localized.isEmpty {
            return localized
        }
        return name
    }

    /// All names (canonical English + every value in `localizationsJSON`),
    /// lowercased and de-duped. Used by Quick DB search, voice parser, and
    /// the recipe estimator so a single query matches against every language
    /// at once — e.g. a Russian user searching "borscht" still hits the row
    /// whose canonical name is "Borscht with white sausage".
    var allSearchableNames: [String] {
        var names: Set<String> = [name]
        if let map = localizationsMap {
            for value in map.values where !value.isEmpty {
                names.insert(value)
            }
        }
        return Array(names)
    }

    private var localizationsMap: [String: String]? {
        guard let json = localizationsJSON,
            let data = json.data(using: .utf8),
            let map = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return nil
        }
        return map
    }
}
