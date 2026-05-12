import Foundation
import OSLog
import SwiftData

/// Loads `polish_food_seed.json` (bundled resource) into the `Food` table
/// on first launch. Idempotent — re-running it is a no-op once the rows
/// are present.
@MainActor
final class FoodSeeder {
    private let container: ModelContainer
    private let resourceName: String
    private let bundle: Bundle

    init(
        container: ModelContainer,
        resourceName: String = "polish_food_seed",
        bundle: Bundle = .main
    ) {
        self.container = container
        self.resourceName = resourceName
        self.bundle = bundle
    }

    /// Seeds the catalog if it's empty. Returns the number of rows inserted.
    @discardableResult
    func seedIfNeeded() throws -> Int {
        let context = ModelContext(container)
        let existing = try context.fetchCount(FetchDescriptor<Food>())
        guard existing == 0 else {
            Logger.persistence.notice("Food catalog already seeded (\(existing) rows)")
            return 0
        }
        let bundle = try load()
        for item in bundle.items {
            context.insert(item.toFood())
        }
        try context.save()
        Logger.persistence.notice(
            "Seeded \(bundle.items.count) catalog items from \(self.resourceName, privacy: .public)")
        return bundle.items.count
    }

    /// Exposed for tests — directly returns the parsed JSON without
    /// touching SwiftData.
    func load() throws -> FoodSeedBundle {
        guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw SeedError.resourceMissing(resourceName)
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
    let name: String
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
        case kcal100g = "kcal_100g"
        case protein100g = "protein_100g"
        case carbs100g = "carbs_100g"
        case fat100g = "fat_100g"
        case defaultPortionGrams = "default_portion_g"
    }

    func toFood() -> Food {
        Food(
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
    }
}
