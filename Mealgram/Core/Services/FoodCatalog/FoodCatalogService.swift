import Foundation
import SwiftData

/// Reads `Food` rows for the Quick Database UI. The Phase-2.5 Supabase
/// path will swap this implementation for one that hits Postgres FTS; the
/// protocol stays the same.
@MainActor
protocol FoodCatalog {
    func categories() throws -> [FoodCategory]
    func all() throws -> [Food]
    func search(_ query: String) throws -> [Food]
    func byCategory(_ category: FoodCategory) throws -> [Food]
}

@MainActor
final class FoodCatalogService: FoodCatalog {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func categories() throws -> [FoodCategory] {
        let foods = try all()
        let uniques = Set(foods.map(\.category))
        return uniques.sorted(by: { $0.rawValue < $1.rawValue })
    }

    func all() throws -> [Food] {
        let context = ModelContext(container)
        return try context.fetch(
            FetchDescriptor<Food>(
                sortBy: [SortDescriptor(\Food.name)]
            ))
    }

    func search(_ query: String) throws -> [Food] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return try all() }
        return try all().filter { food in
            food.name.localizedCaseInsensitiveContains(trimmed)
                || (food.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (food.restaurantName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    func byCategory(_ category: FoodCategory) throws -> [Food] {
        let rawValue = category.rawValue
        let context = ModelContext(container)
        return try context.fetch(
            FetchDescriptor<Food>(
                predicate: #Predicate { $0.categoryRaw == rawValue },
                sortBy: [SortDescriptor(\Food.name)]
            ))
    }
}

extension FoodCategory {
    /// User-visible label for the chip strip.
    var localizedLabel: String {
        switch self {
        case .general: return "Inne"
        case .homemade: return "Domowe"
        case .restaurant: return "Restauracje"
        case .fastFood: return "Fast food"
        case .packaged: return "Pakowane"
        case .beverage: return "Napoje"
        case .snack: return "Przekąski"
        case .produce: return "Owoce / warzywa"
        case .bakery: return "Pieczywo"
        case .dairy: return "Nabiał"
        case .meat: return "Mięso"
        case .seafood: return "Ryby"
        case .sweets: return "Słodycze"
        case .grain: return "Kasze / ryż"
        }
    }
}
