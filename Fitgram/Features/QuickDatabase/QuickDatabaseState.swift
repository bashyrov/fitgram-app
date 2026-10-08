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
    /// drives whether the "My only" filter chip should appear.
    private(set) var hasCustomFoods: Bool = false

    private let catalog: any FoodCatalog
    /// Whole catalogue (~3k rows), fetched once per `refresh()`. Query,
    /// category and "mine only" changes filter this in memory instead of
    /// re-fetching on every keystroke.
    private var allFoods: [Food] = []
    /// Lower-cased name + translations + brand + restaurant per food, built
    /// once per fetch so search doesn't decode localisation JSON per keystroke.
    private var searchKeys: [UUID: String] = [:]

    init(catalog: any FoodCatalog) {
        self.catalog = catalog
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            // Sort by the name the user actually sees (translations differ
            // from the English storage name); compute each once.
            let all = try catalog.all()
                .map { ($0, $0.localizedName) }
                .sorted { $0.1.localizedStandardCompare($1.1) == .orderedAscending }
                .map(\.0)
            allFoods = all
            searchKeys = Dictionary(
                all.map { ($0.id, Self.searchKey(for: $0)) },
                uniquingKeysWith: { first, _ in first })
            availableCategories = Set(all.map(\.category)).sorted { $0.rawValue < $1.rawValue }
            hasCustomFoods = all.contains { !$0.verified }
            applyFilters()
            recentPicks = (try? catalog.recent(limit: 8)) ?? []
            popularPicks = (try? catalog.popular(limit: 8)) ?? []
        } catch {
            Logger.persistence.error("QuickDB refresh failed: \(String(describing: error))")
        }
    }

    /// Returns true when the user hasn't typed a query or picked a
    /// category — the moment the "Ostatnie" + "Frequent" carousels make
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
        applyFilters()
    }

    func selectCategory(_ category: FoodCategory?) async {
        selectedCategory = category
        applyFilters()
    }

    func toggleCustomOnly() async {
        customOnly.toggle()
        applyFilters()
    }

    private func applyFilters() {
        var base = allFoods
        if let selectedCategory {
            base = base.filter { $0.category == selectedCategory }
        }
        if customOnly {
            base = base.filter { !$0.verified }
        }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let needle = trimmed.lowercased()
            base = base.filter { searchKeys[$0.id]?.contains(needle) ?? false }
        }
        foods = base
    }

    private static func searchKey(for food: Food) -> String {
        var parts = food.allSearchableNames
        if let brand = food.brand { parts.append(brand) }
        if let restaurant = food.restaurantName { parts.append(restaurant) }
        return parts.joined(separator: "\n").lowercased()
    }
}
