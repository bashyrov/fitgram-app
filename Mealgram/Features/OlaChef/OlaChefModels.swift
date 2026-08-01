import Foundation

struct OlaChefDish: Identifiable, Equatable, Sendable {
    let id: String
    let localizedNames: [String: String]
    let cuisine: String
    let mealTypes: Set<MealType>
    let tags: Set<OlaChefPreference>
    let servingGrams: Double
    let caloriesKcal: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double
    let prepMinutes: Int
    let ingredients: [OlaChefIngredient]
    let steps: [String]

    func name(languageCode: String = LocalizationStore.currentLanguageCode()) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? localizedNames.values.first ?? id
    }
}

struct OlaChefIngredient: Identifiable, Equatable, Sendable {
    let id: String
    let localizedNames: [String: String]
    let grams: Double
    let caloriesKcal: Double
    let proteinGrams: Double
    let carbsGrams: Double
    let fatGrams: Double

    func scaled(by factor: Double) -> OlaChefIngredient {
        OlaChefIngredient(
            id: id,
            localizedNames: localizedNames,
            grams: grams * factor,
            caloriesKcal: caloriesKcal * factor,
            proteinGrams: proteinGrams * factor,
            carbsGrams: carbsGrams * factor,
            fatGrams: fatGrams * factor
        )
    }

    func name(languageCode: String = LocalizationStore.currentLanguageCode()) -> String {
        localizedNames[languageCode] ?? localizedNames["en"] ?? localizedNames.values.first ?? id
    }
}

enum OlaChefPreference: String, CaseIterable, Identifiable, Sendable {
    case highProtein
    case light
    case quick
    case vegetarian
    case budget
    case noCooking

    var id: String { rawValue }

    var title: String {
        switch self {
        case .highProtein: return L("High protein")
        case .light: return L("Light")
        case .quick: return L("Quick")
        case .vegetarian: return L("Vegetarian")
        case .budget: return L("Budget")
        case .noCooking: return L("No cooking")
        }
    }

    var symbol: String {
        switch self {
        case .highProtein: return "bolt.heart.fill"
        case .light: return "leaf.fill"
        case .quick: return "timer"
        case .vegetarian: return "carrot.fill"
        case .budget: return "banknote.fill"
        case .noCooking: return "snowflake"
        }
    }
}

struct OlaChefRequest: Equatable, Sendable {
    var targetCalories: Int
    var mealType: MealType
    var preferences: Set<OlaChefPreference>
}

struct OlaChefSuggestion: Identifiable, Equatable, Sendable {
    let id: String
    let dish: OlaChefDish
    let factor: Double
    let targetCalories: Int
    let score: Double

    var servingGrams: Double { dish.servingGrams * factor }
    var caloriesKcal: Double { dish.caloriesKcal * factor }
    var proteinGrams: Double { dish.proteinGrams * factor }
    var carbsGrams: Double { dish.carbsGrams * factor }
    var fatGrams: Double { dish.fatGrams * factor }
    var ingredients: [OlaChefIngredient] { dish.ingredients.map { $0.scaled(by: factor) } }

    func name(languageCode: String = LocalizationStore.currentLanguageCode()) -> String {
        dish.name(languageCode: languageCode)
    }

    func foodItems(languageCode: String = LocalizationStore.currentLanguageCode()) -> [FoodItem] {
        ingredients.map { ingredient in
            FoodItem(
                name: ingredient.name(languageCode: languageCode),
                quantityGrams: ingredient.grams,
                caloriesKcal: ingredient.caloriesKcal,
                proteinGrams: ingredient.proteinGrams,
                carbsGrams: ingredient.carbsGrams,
                fatGrams: ingredient.fatGrams,
                confidence: 0.95
            )
        }
    }
}

