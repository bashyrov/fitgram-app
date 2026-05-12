import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class QuickDatabaseState {
    private(set) var foods: [Food] = []
    private(set) var availableCategories: [FoodCategory] = []
    var selectedCategory: FoodCategory?
    var query: String = ""
    private(set) var isLoading = false

    private let catalog: any FoodCatalog

    init(catalog: any FoodCatalog) {
        self.catalog = catalog
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            availableCategories = try catalog.categories()
            foods = try filteredFoods()
        } catch {
            Logger.persistence.error("QuickDB refresh failed: \(String(describing: error))")
        }
    }

    /// Convenience for the search field's `.onChange`.
    func applyQuery(_ raw: String) async {
        query = raw
        await refresh()
    }

    func selectCategory(_ category: FoodCategory?) async {
        selectedCategory = category
        await refresh()
    }

    private func filteredFoods() throws -> [Food] {
        let base: [Food]
        if let selectedCategory {
            base = try catalog.byCategory(selectedCategory)
        } else {
            base = try catalog.all()
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return base }
        return base.filter { food in
            food.name.localizedCaseInsensitiveContains(trimmed)
                || (food.brand?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || (food.restaurantName?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }
}
