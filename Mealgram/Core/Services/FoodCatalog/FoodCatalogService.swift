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
    /// Most-recently-picked foods, newest first.
    func recent(limit: Int) throws -> [Food]
    /// Foods sorted by pickCount desc.
    func popular(limit: Int) throws -> [Food]
    /// Increments pickCount + stamps lastPickedAt. Called after the user
    /// commits a Quick DB entry to their meal log.
    func recordPick(_ food: Food) throws
    /// Inserts a user-authored Food into the catalogue. Returns the
    /// persisted row.
    @discardableResult
    func create(_ food: Food) throws -> Food
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

    func recent(limit: Int) throws -> [Food] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Food>(
            predicate: #Predicate { $0.lastPickedAt != nil },
            sortBy: [SortDescriptor(\Food.lastPickedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func popular(limit: Int) throws -> [Food] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Food>(
            predicate: #Predicate { $0.pickCount > 0 },
            sortBy: [SortDescriptor(\Food.pickCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func recordPick(_ food: Food) throws {
        let context = ModelContext(container)
        let foodID = food.id
        let descriptor = FetchDescriptor<Food>(predicate: #Predicate { $0.id == foodID })
        guard let attached = try context.fetch(descriptor).first else { return }
        attached.pickCount += 1
        attached.lastPickedAt = Date()
        try context.save()
    }

    @discardableResult
    func create(_ food: Food) throws -> Food {
        let context = ModelContext(container)
        context.insert(food)
        try context.save()
        return food
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
