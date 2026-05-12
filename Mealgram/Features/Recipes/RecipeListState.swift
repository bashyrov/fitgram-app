import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class RecipeListState {
    private(set) var recipes: [Recipe] = []
    private(set) var isLoading = false
    var query: String = ""

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
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return recipes }
        return recipes.filter { recipe in
            recipe.title.localizedCaseInsensitiveContains(trimmed)
                || recipe.ingredients.contains { ingredient in
                    ingredient.name.localizedCaseInsensitiveContains(trimmed)
                }
        }
    }
}
