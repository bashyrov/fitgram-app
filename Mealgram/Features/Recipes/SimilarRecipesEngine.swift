import Foundation

/// Pure-function recipe similarity ranker. Counts shared ≥4-char
/// ingredient tokens between a source recipe and each candidate; the
/// top-scored neighbours surface in the detail view as "Co podobnego?".
struct SimilarRecipesEngine {
    /// Returns up to `limit` recipes ranked by overlapping ingredient
    /// tokens with `source`. Excludes the source itself + recipes with
    /// zero token overlap (they're not actually similar).
    static func similar(to source: Recipe, in pool: [Recipe], limit: Int = 3) -> [Recipe] {
        let sourceTokens = tokens(in: source)
        guard !sourceTokens.isEmpty else { return [] }
        let scored = pool.compactMap { candidate -> (Recipe, Int)? in
            guard candidate.id != source.id else { return nil }
            let shared = tokens(in: candidate).intersection(sourceTokens).count
            return shared > 0 ? (candidate, shared) : nil
        }
        return
            scored
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }
            .prefix(limit)
            .map(\.0)
    }

    /// Lowercased ≥4-char token set built from the recipe's ingredient
    /// names. Same approach RecipeNutritionEstimator uses so the
    /// thresholds stay consistent across features.
    static func tokens(in recipe: Recipe) -> Set<String> {
        let combined = recipe.ingredients.map(\.name).joined(separator: " ").lowercased()
        return Set(
            combined.split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 4 }
        )
    }
}
