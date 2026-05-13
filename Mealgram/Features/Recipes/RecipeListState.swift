import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class RecipeListState {
    enum Sort: String, CaseIterable, Sendable {
        case recent
        case nameAsc
        case cookedCount
        case ratingDesc

        var label: String {
            switch self {
            case .recent: return String(localized: "Najnowsze")
            case .nameAsc: return String(localized: "Nazwa")
            case .cookedCount: return String(localized: "Najczęściej gotowane")
            case .ratingDesc: return String(localized: "Najwyższa ocena")
            }
        }
    }

    private(set) var recipes: [Recipe] = []
    private(set) var isLoading = false
    var query: String = ""
    var sort: Sort = .recent
    var favoritesOnly: Bool = false

    private let repository: RecipeRepository

    init(repository: RecipeRepository) {
        self.repository = repository
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            recipes = try repository.all()
        } catch {
            Logger.persistence.error("Recipe refresh failed: \(String(describing: error))")
            recipes = []
        }
    }

    var filtered: [Recipe] {
        let queried = filteredByQuery
        let favorited = favoritesOnly ? queried.filter(\.isFavorite) : queried
        return Self.sort(favorited, by: sort)
    }

    private var filteredByQuery: [Recipe] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recipes }
        return recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(trimmed)
                || recipe.ingredients.contains { ingredient in
                    ingredient.name.localizedCaseInsensitiveContains(trimmed)
                }
        }
    }

    /// Public for tests — pure sort over a list.
    static func sort(_ recipes: [Recipe], by option: Sort) -> [Recipe] {
        switch option {
        case .recent:
            return recipes.sorted { $0.updatedAt > $1.updatedAt }
        case .nameAsc:
            return recipes.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .cookedCount:
            return recipes.sorted {
                if $0.cookCount != $1.cookCount { return $0.cookCount > $1.cookCount }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .ratingDesc:
            return recipes.sorted {
                let lhs = $0.rating ?? 0
                let rhs = $1.rating ?? 0
                if lhs != rhs { return lhs > rhs }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
}
