import Foundation
import OSLog

/// Pro-only AI meal ideas. Answers are cached for the current week per
/// (meal type, preferences, ~100 kcal target, language), so tapping
/// "generate" again re-uses last answer instead of paying for a new one.
struct WorkerOlaChefService: Sendable {
    private let client: any APIClient
    private let cache: OlaChefAICache

    init(client: any APIClient, cache: OlaChefAICache = OlaChefAICache()) {
        self.client = client
        self.cache = cache
    }

    func suggestions(
        for request: OlaChefRequest,
        excluding existingNames: [String],
        locale: String = LocalizationStore.currentLanguageCode()
    ) async -> [OlaChefSuggestion] {
        let key = OlaChefAICache.key(for: request, locale: locale)
        if let cached = cache.load(key: key) {
            return Self.decode(cached, targetCalories: request.targetCalories)
        }
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
            if !response.suggestions.isEmpty, let data = try? JSONEncoder.fitgram.encode(response) {
                cache.save(data, key: key)
            }
            return response.suggestions.map { $0.toDomain(targetCalories: request.targetCalories) }
        } catch {
            Logger.networking.error("Kuchnia Oli AI suggestions failed: \(String(describing: error))")
            return []
        }
    }

    private static func decode(_ data: Data, targetCalories: Int) -> [OlaChefSuggestion] {
        guard let response = try? JSONDecoder.fitgram.decode(WorkerOlaChefResponse.self, from: data) else {
            return []
        }
        return response.suggestions.map { $0.toDomain(targetCalories: targetCalories) }
    }
}

/// Week-scoped store for raw Ola Chef AI responses. Rolls over (and drops
/// every entry) on the first read of a new ISO week.
struct OlaChefAICache: Sendable {
    private static let storageKey = "olaChef.aiCache"
    private let defaults: UserDefaults
    private let now: @Sendable () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping @Sendable () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    static func key(for request: OlaChefRequest, locale: String) -> String {
        let bucket = Int((Double(request.targetCalories) / 100).rounded()) * 100
        let preferences = request.preferences.map(\.rawValue).sorted().joined(separator: ",")
        return "\(locale)|\(request.mealType.rawValue)|\(preferences)|\(bucket)"
    }

    func load(key: String) -> Data? {
        currentEntries()[key]
    }

    func save(_ data: Data, key: String) {
        var entries = currentEntries()
        entries[key] = data
        defaults.set(["week": weekToken(), "entries": entries] as [String: Any], forKey: Self.storageKey)
    }

    private func currentEntries() -> [String: Data] {
        guard let stored = defaults.dictionary(forKey: Self.storageKey),
            stored["week"] as? String == weekToken()
        else { return [:] }
        return stored["entries"] as? [String: Data] ?? [:]
    }

    private func weekToken() -> String {
        let comps = Calendar.fitgramLocalDay.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now())
        return "\(comps.yearForWeekOfYear ?? 0)-W\(comps.weekOfYear ?? 0)"
    }
}

private struct WorkerOlaChefRequest: Encodable, Sendable {
    var targetCalories: Int
    var mealType: String
    var preferences: [String]
    var locale: String
    var excludeDishNames: [String]
}

private struct WorkerOlaChefResponse: Codable, Sendable {
    var suggestions: [WorkerOlaChefSuggestion]
    var rawAINotes: String?
}

private struct WorkerOlaChefSuggestion: Codable, Sendable {
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

private struct WorkerOlaChefIngredient: Codable, Sendable {
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
