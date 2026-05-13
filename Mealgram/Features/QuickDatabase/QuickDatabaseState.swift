import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class QuickDatabaseState {
    private(set) var foods: [Food] = []
    private(set) var availableCategories: [FoodCategory] = []
    private(set) var recentPicks: [Food] = []
    private(set) var popularPicks: [Food] = []
    var selectedCategory: FoodCategory?
    var query: String = ""
    /// Filter to user-authored (verified == false) Food rows.
    var customOnly: Bool = false
    private(set) var isLoading = false
    /// True when the catalogue holds at least one user-authored row;
    /// drives whether the "Tylko moje" filter chip should appear.
    private(set) var hasCustomFoods: Bool = false

    private let catalog: any FoodCatalog

    init(catalog: any FoodCatalog) {
        self.catalog = catalog
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            availableCategories = try catalog.categories()
            let all = try catalog.all()
            hasCustomFoods = all.contains { !$0.verified }
            foods = try filteredFoods()
            recentPicks = (try? catalog.recent(limit: 8)) ?? []
            popularPicks = (try? catalog.popular(limit: 8)) ?? []
        } catch {
            Logger.persistence.error("QuickDB refresh failed: \(String(describing: error))")
        }
    }

    /// Returns true when the user hasn't typed a query or picked a
    /// category — the moment the "Ostatnie" + "Częste" carousels make
    /// sense to display at the top of the list.
    var shouldShowSuggestions: Bool {
        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && selectedCategory == nil
            && (!recentPicks.isEmpty || !popularPicks.isEmpty)
    }

    func recordPick(_ food: Food) {
        try? catalog.recordPick(food)
    }

    func createCustomFood(_ food: Food) async {
        do {
            try catalog.create(food)
            await refresh()
        } catch {
            Logger.persistence.error("Custom food create failed: \(String(describing: error))")
        }
    }

    func resetPickHistory() async {
        do {
            try catalog.resetPickHistory()
            await refresh()
        } catch {
            Logger.persistence.error("Pick history reset failed: \(String(describing: error))")
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

    func toggleCustomOnly() async {
        customOnly.toggle()
        await refresh()
    }

    private func filteredFoods() throws -> [Food] {
        var base: [Food]
        if let selectedCategory {
            base = try catalog.byCategory(selectedCategory)
        } else {
            base = try catalog.all()
        }
        if customOnly {
            base = base.filter { !$0.verified }
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
