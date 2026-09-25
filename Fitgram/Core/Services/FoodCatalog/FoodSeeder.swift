import Foundation
import OSLog
import SwiftData

/// Loads bundled seed files into the `Food` catalog table. Tries both the
/// legacy Polish seed and the new international catalog and de-dupes by
/// remote ID so re-runs are idempotent. Bumps to international expansion
/// for already-seeded installs by inserting only the diff.
@MainActor
final class FoodSeeder {
    private let container: ModelContainer
    private let resourceNames: [String]
    private let bundle: Bundle

    init(
        container: ModelContainer,
        resourceNames: [String] = ["international_food_seed", "polish_food_seed"],
        bundle: Bundle = .main
    ) {
        self.container = container
        self.resourceNames = resourceNames
        self.bundle = bundle
    }

    /// Seeds the catalog. Additive — runs on every cold start but only
    /// inserts rows whose `remoteID` isn't already present, so existing
    /// users automatically pick up new international entries without
    /// duplicates. Also refreshes `localizationsJSON` on existing rows so
    /// translation updates land without re-seeding. Returns the number of
    /// rows inserted.
    @discardableResult
    func seedIfNeeded() throws -> Int {
        let context = ModelContext(container)
        let existingFoods = try context.fetch(FetchDescriptor<Food>())
        var existingByID = [String: Food]()
        existingFoods.forEach { food in
            guard let remoteID = food.remoteID, existingByID[remoteID] == nil else { return }
            existingByID[remoteID] = food
        }

        var inserted = 0
        var refreshed = 0
        for resource in resourceNames {
            guard let bundleData = try? loadBundle(for: resource) else { continue }
            for item in bundleData.items {
                if let existing = existingByID[item.id] {
                    let newJSON = item.localizationsJSONPayload()
                    if existing.localizationsJSON != newJSON {
                        existing.localizationsJSON = newJSON
                        refreshed += 1
                    }
                } else {
                    let food = item.toFood()
                    context.insert(food)
                    existingByID[item.id] = food
                    inserted += 1
                }
            }
        }
        if inserted > 0 || refreshed > 0 {
            try context.save()
            Logger.persistence.notice(
                "Seeded \(inserted) new + refreshed \(refreshed) translations (existing: \(existingFoods.count))"
            )
        } else {
            Logger.persistence.notice("Food catalog up to date (\(existingFoods.count) rows)")
        }
        return inserted
    }

    /// Exposed for tests — returns every seed file merged into one bundle.
    /// Schema version is taken from the first bundle that loads; items are
    /// concatenated in the order `resourceNames` declares.
    func load() throws -> FoodSeedBundle {
        var schema: String?
        var merged: [FoodSeedItem] = []
        for resource in resourceNames {
            guard let bundleData = try? loadBundle(for: resource) else { continue }
            schema = schema ?? bundleData.schemaVersion
            merged.append(contentsOf: bundleData.items)
        }
        guard let schema else {
            throw SeedError.resourceMissing(resourceNames.joined(separator: ","))
        }
        return FoodSeedBundle(schemaVersion: schema, items: merged)
    }

    private func loadBundle(for resource: String) throws -> FoodSeedBundle {
        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            throw SeedError.resourceMissing(resource)
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(FoodSeedBundle.self, from: data)
    }

    enum SeedError: Error, Equatable {
        case resourceMissing(String)
    }
}

// MARK: - Wire format

struct FoodSeedBundle: Decodable, Equatable {
    let schemaVersion: String
    let items: [FoodSeedItem]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case items
    }
}

struct FoodSeedItem: Decodable, Equatable {
    let id: String
    /// Canonical English name. Used as the storage key and the fallback for
    /// any locale without a translation.
    let name: String
    /// Optional per-locale translations keyed by ISO 639-1 language code
    /// ("pl", "uk", "ru", "es"). Values override `name` at display time when
    /// the user's current locale matches.
    let localizedNames: [String: String]?
    let category: String
    let brand: String?
    let restaurant: String?
    let kcal100g: Double
    let protein100g: Double
    let carbs100g: Double
    let fat100g: Double
    let defaultPortionGrams: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, category, brand
        case restaurant
        case localizedNames = "localized_names"
        case kcal100g = "kcal_100g"
        case protein100g = "protein_100g"
        case carbs100g = "carbs_100g"
        case fat100g = "fat_100g"
        case defaultPortionGrams = "default_portion_g"
    }

    /// JSON-encoded representation of `localizedNames` for the SwiftData
    /// `Food.localizationsJSON` column. Nil when the seed item has no map.
    func localizationsJSONPayload() -> String? {
        guard let localizedNames, !localizedNames.isEmpty,
            let data = try? JSONEncoder().encode(localizedNames),
            let json = String(data: data, encoding: .utf8)
        else { return nil }
        return json
    }

    func toFood() -> Food {
        let food = Food(
            remoteID: id,
            name: name,
            brand: brand,
            restaurantName: restaurant,
            category: FoodCategory(rawValue: category) ?? .general,
            caloriesKcalPer100g: kcal100g,
            proteinGramsPer100g: protein100g,
            carbsGramsPer100g: carbs100g,
            fatGramsPer100g: fat100g,
            fiberGramsPer100g: nil,
            defaultPortionGrams: defaultPortionGrams,
            verified: true
        )
        if let localizedNames, !localizedNames.isEmpty,
            let data = try? JSONEncoder().encode(localizedNames),
            let json = String(data: data, encoding: .utf8)
        {
            food.localizationsJSON = json
        }
        return food
    }
}
