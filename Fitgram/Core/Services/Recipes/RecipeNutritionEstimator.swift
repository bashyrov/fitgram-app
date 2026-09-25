import Foundation

/// Pure-function nutrition estimator. Given a list of ingredient names +
/// a list of catalog `Food` entries, finds the best name match for each
/// ingredient and sums the per-100g values weighted by either the
/// supplied gram amount or the catalog's `defaultPortionGrams`.
///
/// Lives outside `RecipeRepository` so the math is unit-testable without
/// SwiftData, and so the UI can preview the estimate before committing.
struct RecipeNutritionEstimator {
    struct Estimate: Equatable, Sendable {
        let perServingCalories: Double
        let perServingProtein: Double
        let perServingCarbs: Double
        let perServingFat: Double
        /// Names from the input that didn't match any catalog row. Surfaced
        /// in the UI so the user knows the estimate is partial.
        let unmatched: [String]
        /// How many input ingredients did get matched.
        let matched: Int
    }

    let catalog: [Food]
    /// How many grams of an ingredient to assume when neither the
    /// ingredient nor the catalog row has a default portion. Conservative
    /// "small handful" guess so the estimate doesn't blow up.
    let fallbackGrams: Double = 80

    func estimate(
        ingredients: [Ingredient],
        servings: Int
    ) -> Estimate {
        guard servings > 0 else {
            return Estimate(
                perServingCalories: 0, perServingProtein: 0,
                perServingCarbs: 0, perServingFat: 0,
                unmatched: ingredients.map(\.name), matched: 0
            )
        }
        var totalKcal: Double = 0
        var totalProtein: Double = 0
        var totalCarbs: Double = 0
        var totalFat: Double = 0
        var unmatched: [String] = []
        var matched = 0
        for ingredient in ingredients {
            guard let food = bestMatch(for: ingredient.name) else {
                unmatched.append(ingredient.name)
                continue
            }
            let grams = ingredient.quantityGrams ?? food.defaultPortionGrams ?? fallbackGrams
            let factor = grams / 100.0
            totalKcal += food.caloriesKcalPer100g * factor
            totalProtein += food.proteinGramsPer100g * factor
            totalCarbs += food.carbsGramsPer100g * factor
            totalFat += food.fatGramsPer100g * factor
            matched += 1
        }
        let portions = Double(servings)
        return Estimate(
            perServingCalories: totalKcal / portions,
            perServingProtein: totalProtein / portions,
            perServingCarbs: totalCarbs / portions,
            perServingFat: totalFat / portions,
            unmatched: unmatched,
            matched: matched
        )
    }

    /// Public for tests — the match function. Returns nil when no row
    /// contains a meaningful token from the ingredient.
    func bestMatch(for ingredientName: String) -> Food? {
        let cleaned = ingredientName.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Exact name match wins (any language).
        if let exact = catalog.first(where: { food in
            food.allSearchableNames.contains { $0.lowercased() == cleaned }
        }) {
            return exact
        }

        // Otherwise, find any catalog row whose name shares the most
        // significant tokens (length ≥ 4) with the ingredient. Pool tokens
        // from every localization so a recipe written in any language still
        // matches.
        let tokens = Self.tokenize(cleaned)
        guard !tokens.isEmpty else { return nil }
        var bestScore = 0
        var best: Food?
        for food in catalog {
            var foodTokens: Set<String> = []
            for n in food.allSearchableNames {
                foodTokens.formUnion(Self.tokenize(n.lowercased()))
            }
            let shared = tokens.intersection(foodTokens).count
            if shared > bestScore {
                bestScore = shared
                best = food
            }
        }
        return bestScore > 0 ? best : nil
    }

    private static func tokenize(_ text: String) -> Set<String> {
        Set(
            text.split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 4 }
        )
    }

    struct Ingredient: Sendable {
        let name: String
        let quantityGrams: Double?
    }
}
