import Foundation

struct OlaChefCatalog: Sendable {
    let dishes: [OlaChefDish]

    static let shared = OlaChefCatalog(dishes: OlaChefCatalog.makeCatalog())

    func suggestions(for request: OlaChefRequest, limit: Int = 18) -> [OlaChefSuggestion] {
        let ranked = dishes.compactMap { dish -> OlaChefSuggestion? in
            guard dish.caloriesKcal > 0 else { return nil }
            let factor = Double(request.targetCalories) / dish.caloriesKcal
            guard factor >= 0.55, factor <= 1.9 else { return nil }
            let scaledGrams = dish.servingGrams * factor
            guard scaledGrams >= 140, scaledGrams <= 850 else { return nil }

            let calorieDistance = abs(Double(request.targetCalories) - dish.caloriesKcal * factor)
            let mealBonus = dish.mealTypes.contains(request.mealType) ? 26.0 : -12.0
            let preferenceBonus = Double(dish.tags.intersection(request.preferences).count) * 12.0
            let quickBonus = request.preferences.contains(.quick) && dish.prepMinutes <= 20 ? 8.0 : 0.0
            let proteinBonus =
                request.preferences.contains(.highProtein) ? min(18, dish.proteinGrams * factor * 0.35) : 0.0
            let realismPenalty = abs(1.0 - factor) * 9.0
            let score =
                100 - calorieDistance * 0.05 + mealBonus + preferenceBonus + quickBonus + proteinBonus - realismPenalty
            return OlaChefSuggestion(
                id: "\(dish.id)-\(request.targetCalories)",
                dish: dish,
                factor: factor,
                targetCalories: request.targetCalories,
                score: score
            )
        }
        .sorted {
            if abs($0.score - $1.score) > 0.01 { return $0.score > $1.score }
            return $0.dish.cuisine < $1.dish.cuisine
        }

        var seenDishFamilies = Set<String>()
        var unique: [OlaChefSuggestion] = []
        unique.reserveCapacity(limit)
        for suggestion in ranked {
            let key = suggestionDisplayFamilyKey(suggestion.dish.id)
            guard !seenDishFamilies.contains(key) else { continue }
            seenDishFamilies.insert(key)
            unique.append(suggestion)
            if unique.count == limit { break }
        }
        return unique
    }

    private func suggestionDisplayFamilyKey(_ id: String) -> String {
        if let templateRange = id.range(of: ".template.") {
            let suffix = id[templateRange.upperBound...]
            let templateIndex = suffix.split(separator: ".").first.map(String.init) ?? String(suffix)
            return "template.\(templateIndex)"
        }
        let parts = id.split(separator: ".").map(String.init)
        if let last = parts.last, Self.styleIDs.contains(last) {
            return parts.dropLast().joined(separator: ".")
        }
        return id
    }
    static func makeCatalog() -> [OlaChefDish] {
        let base = baseDishes() + generatedBaseDishes()
        let styles: [Style] = [
            Style(id: "classic", multiplier: 1.00, extraTags: []),
            Style(id: "protein", multiplier: 1.08, extraTags: [.highProtein]),
            Style(id: "light", multiplier: 0.78, extraTags: [.light]),
            Style(id: "quick", multiplier: 0.92, extraTags: [.quick]),
            Style(id: "budget", multiplier: 0.88, extraTags: [.budget]),
            Style(id: "vegetarian", multiplier: 0.86, extraTags: [.vegetarian]),
            Style(id: "no-cook", multiplier: 0.74, extraTags: [.noCooking, .quick]),
            Style(id: "family", multiplier: 1.18, extraTags: []),
            Style(id: "post-workout", multiplier: 1.24, extraTags: [.highProtein]),
            Style(id: "small", multiplier: 0.64, extraTags: [.light]),
            Style(id: "large", multiplier: 1.42, extraTags: []),
            Style(id: "balanced", multiplier: 0.98, extraTags: [.quick]),
        ]

        return base.flatMap { dish in
            styles.map { style in
                variant(of: dish, style: style.id, multiplier: style.multiplier, extraTags: style.extraTags)
            }
        }
    }

    /// Portion/tag preset applied to every base dish to fan the catalog out.
    private struct Style {
        let id: String
        let multiplier: Double
        let extraTags: Set<OlaChefPreference>
    }

    private static func variant(
        of dish: OlaChefDish,
        style: String,
        multiplier: Double,
        extraTags: Set<OlaChefPreference>
    ) -> OlaChefDish {
        let suffixes = styleSuffixes[style] ?? [:]
        let localized = dish.localizedNames.reduce(into: [String: String]()) { result, pair in
            let suffix = suffixes[pair.key] ?? suffixes["en"] ?? ""
            result[pair.key] = suffix.isEmpty ? pair.value : "\(pair.value) \(suffix)"
        }
        return OlaChefDish(
            id: "\(dish.id).\(style)",
            localizedNames: localized,
            cuisine: dish.cuisine,
            mealTypes: dish.mealTypes,
            tags: dish.tags.union(extraTags),
            servingGrams: dish.servingGrams * multiplier,
            caloriesKcal: dish.caloriesKcal * multiplier,
            proteinGrams: dish.proteinGrams * (extraTags.contains(.highProtein) ? multiplier * 1.18 : multiplier),
            carbsGrams: dish.carbsGrams * multiplier,
            fatGrams: dish.fatGrams * (extraTags.contains(.light) ? multiplier * 0.78 : multiplier),
            prepMinutes: max(5, Int(Double(dish.prepMinutes) * (extraTags.contains(.quick) ? 0.72 : 1.0))),
            ingredients: dish.ingredients.map { $0.scaled(by: multiplier) },
            steps: dish.steps
        )
    }

    /// One bundled dish row. Memberwise-initialised so the data table in
    /// `OlaChefCatalog+Dishes.swift` reads as labelled columns.
    struct DishSpec {
        let id: String
        let name: String
        var localizedNames: [String: String]?
        let cuisine: String
        let mealTypes: Set<MealType>
        let tags: Set<OlaChefPreference>
        let grams: Double
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        let prep: Int
        let ingredients: [IngredientSpec]

        var dish: OlaChefDish {
            OlaChefDish(
                id: id,
                localizedNames: localizedNames ?? OlaChefCatalog.names(name),
                cuisine: cuisine,
                mealTypes: mealTypes,
                tags: tags,
                servingGrams: grams,
                caloriesKcal: kcal,
                proteinGrams: protein,
                carbsGrams: carbs,
                fatGrams: fat,
                prepMinutes: prep,
                ingredients: ingredients.enumerated().map { index, ingredient in
                    OlaChefIngredient(
                        id: "\(id).i\(index)",
                        localizedNames: OlaChefCatalog.names(ingredient.name),
                        grams: ingredient.grams,
                        caloriesKcal: ingredient.kcal,
                        proteinGrams: ingredient.protein,
                        carbsGrams: ingredient.carbs,
                        fatGrams: ingredient.fat
                    )
                },
                steps: [
                    L("Prepare ingredients and weigh the portion."),
                    L("Cook or assemble the base, then add protein and vegetables."),
                    L("Season lightly and serve the suggested portion."),
                ]
            )
        }
    }

    struct IngredientSpec {
        let name: String
        let grams: Double
        let kcal: Double
        let protein: Double
        let carbs: Double
        let fat: Double
    }

    static func names(_ en: String) -> [String: String] {
        localizedTerms[en] ?? ["en": en, "pl": en, "uk": en, "ru": en, "es": en]
    }

    static func localizedCuisineName(
        _ cuisine: String, languageCode: String = LocalizationStore.currentLanguageCode()
    ) -> String {
        let names = cuisineNames[cuisine]
        return names?[languageCode] ?? names?["en"] ?? cuisine
    }

    private static let styleIDs: Set<String> = Set(styleSuffixes.keys)
}
