import Foundation
import OSLog

struct WorkerOlaChefService: Sendable {
    private let client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    func suggestions(
        for request: OlaChefRequest,
        excluding existingNames: [String],
        locale: String = LocalizationStore.currentLanguageCode()
    ) async -> [OlaChefSuggestion] {
        do {
            let payload = WorkerOlaChefRequest(
                targetCalories: request.targetCalories,
                mealType: request.mealType.rawValue,
                preferences: request.preferences.map(\.rawValue).sorted(),
                locale: locale,
                excludeDishNames: existingNames
            )
            let endpoint = try Endpoint.json(
                path: "/api/v1/ola-chef/suggestions",
                payload: payload,
                requiresAuth: false
            )
            let response = try await client.send(endpoint, expecting: WorkerOlaChefResponse.self)
            return response.suggestions.map { $0.toDomain(targetCalories: request.targetCalories) }
        } catch {
            Logger.networking.error("Kuchnia Oli AI suggestions failed: \(String(describing: error))")
            return []
        }
    }
}

private struct WorkerOlaChefRequest: Encodable, Sendable {
    var targetCalories: Int
    var mealType: String
    var preferences: [String]
    var locale: String
    var excludeDishNames: [String]
}

private struct WorkerOlaChefResponse: Decodable, Sendable {
    var suggestions: [WorkerOlaChefSuggestion]
    var rawAINotes: String?
}

private struct WorkerOlaChefSuggestion: Decodable, Sendable {
    var id: String
    var name: String
    var cuisine: String
    var servingGrams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var prepMinutes: Int
    var ingredients: [WorkerOlaChefIngredient]
    var steps: [String]
    var confidence: Double

    func toDomain(targetCalories: Int) -> OlaChefSuggestion {
        let dish = OlaChefDish(
            id: "ai.\(id)",
            localizedNames: Self.localizedMap(name),
            cuisine: cuisine,
            mealTypes: Set(MealType.allCases),
            tags: [],
            servingGrams: servingGrams,
            caloriesKcal: caloriesKcal,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams,
            prepMinutes: prepMinutes,
            ingredients: ingredients.enumerated().map { index, ingredient in
                ingredient.toDomain(id: "ai.\(id).i\(index)")
            },
            steps: steps
        )
        return OlaChefSuggestion(
            id: "ai.\(id)-\(targetCalories)",
            dish: dish,
            factor: 1,
            targetCalories: targetCalories,
            score: 96 + confidence
        )
    }

    private static func localizedMap(_ value: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: ["pl", "en", "uk", "ru", "es"].map { ($0, value) })
    }
}

private struct WorkerOlaChefIngredient: Decodable, Sendable {
    var name: String
    var grams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double

    func toDomain(id: String) -> OlaChefIngredient {
        OlaChefIngredient(
            id: id,
            localizedNames: Dictionary(uniqueKeysWithValues: ["pl", "en", "uk", "ru", "es"].map { ($0, name) }),
            grams: grams,
            caloriesKcal: caloriesKcal,
            proteinGrams: proteinGrams,
            carbsGrams: carbsGrams,
            fatGrams: fatGrams
        )
    }
}
