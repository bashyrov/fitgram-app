import Foundation
import OSLog

struct MealTextAnalysis: Sendable, Equatable {
    var overall: ScanResult.DetectedItem
    var items: [ScanResult.DetectedItem]
    var suggestedMealType: MealType
    var confidence: Double
    var rawAINotes: String?

    var detailedResult: ScanResult {
        ScanResult(
            items: items,
            suggestedMealType: suggestedMealType,
            confidence: confidence,
            rawAINotes: rawAINotes
        )
    }

    var overallResult: ScanResult {
        ScanResult(
            items: [overall],
            suggestedMealType: suggestedMealType,
            confidence: confidence,
            rawAINotes: rawAINotes
        )
    }
}

struct MealTextAnalysisService: @unchecked Sendable {
    enum QuotaKind: String, Codable, Sendable {
        case draftMeal = "ai_draft_meal"
        case loggedMeal = "ai_logged_meal"
        case mealRefresh = "ai_meal_refresh"
        case productNutrition = "ai_product_nutrition"
    }

    private let client: (any APIClient)?
    private let fallbackParser: VoiceMealParser
    private let catalogSnapshot: [Food]
    private let foodCatalog: (any FoodCatalog)?

    init(client: (any APIClient)? = nil, catalog: [Food] = [], foodCatalog: (any FoodCatalog)? = nil) {
        self.client = client
        self.catalogSnapshot = catalog
        self.foodCatalog = foodCatalog
        self.fallbackParser = VoiceMealParser(catalog: catalog)
    }

    func analyze(
        text: String,
        mealType: MealType,
        locale: String = LocalizationStore.currentLanguageCode(),
        quotaKind: QuotaKind = .mealRefresh
    ) async
        -> MealTextAnalysis
    {
        if let client {
            do {
                let payload = Request(
                    text: text,
                    mealTypeHint: mealType.rawValue,
                    locale: locale,
                    quotaKind: quotaKind.rawValue
                )
                let endpoint = try Endpoint.json(
                    path: "/api/v1/analyze-meal-text",
                    payload: payload,
                    requiresAuth: true
                )
                let response = try await client.send(endpoint, expecting: Response.self)
                return await enrichAndCache(response.toDomain(fallbackMealType: mealType))
            } catch {
                Logger.networking.error("Meal text AI failed, using local fallback: \(String(describing: error))")
            }
        }
        return await enrichAndCache(fallback(text: text, mealType: mealType))
    }

    func complete(items: [FoodItem], mealType: MealType) async -> [FoodItem] {
        let catalog = await currentCatalog()
        var resolved = items.map { resolve(item: $0, catalog: catalog).item }
        let missingIndexes = resolved.indices.filter { needsNutrition(resolved[$0]) }
        guard !missingIndexes.isEmpty else { return resolved }

        let text =
            missingIndexes
            .map { index in
                let item = resolved[index]
                let caloriesHint = item.caloriesKcal > 0 ? ", \(Int(item.caloriesKcal.rounded())) kcal" : ""
                return "\(Int(item.quantityGrams.rounded())) g \(item.name)\(caloriesHint)"
            }
            .joined(separator: ", ")
        guard !text.isEmpty else { return resolved }

        let analysis = await analyze(text: text, mealType: mealType, quotaKind: .productNutrition)
        let aiItems = analysis.items.isEmpty ? [analysis.overall] : analysis.items
        var usedAIIndexes: Set<Int> = []

        for index in missingIndexes {
            let original = resolved[index]
            guard let match = bestAIItem(for: original, in: aiItems, usedIndexes: usedAIIndexes) else { continue }
            usedAIIndexes.insert(match.index)
            resolved[index] = merge(original: original, ai: match.item)
        }
        return resolved
    }

    func complete(item: FoodItem, mealType: MealType) async -> (item: FoodItem, usedAI: Bool) {
        let catalog = await currentCatalog()
        let resolved = resolve(item: item, catalog: catalog)
        guard needsNutrition(resolved.item) else {
            return (resolved.item, false)
        }

        let completed = await complete(items: [resolved.item], mealType: mealType).first ?? resolved.item
        return (completed, client != nil && !resolved.matchedCatalog)
    }

    func complete(result: ScanResult) async -> ScanResult {
        let items = result.items.map { item in
            FoodItem(
                id: item.id,
                name: item.name,
                quantityGrams: item.quantityGrams,
                caloriesKcal: item.caloriesKcal,
                proteinGrams: item.proteinGrams,
                carbsGrams: item.carbsGrams,
                fatGrams: item.fatGrams,
                confidence: item.confidence
            )
        }
        let completed = await complete(items: items, mealType: result.suggestedMealType)
        return ScanResult(
            items: completed.map(Self.detectedItem(from:)),
            suggestedMealType: result.suggestedMealType,
            confidence: result.confidence,
            rawAINotes: result.rawAINotes
        )
    }

    private func fallback(text: String, mealType: MealType) -> MealTextAnalysis {
        let items = fallbackParser.parseMultiple(text).map(Self.detectedItem(from:))
        let overallName =
            items.count == 1
            ? items[0].name
            : items.map(\.name).joined(separator: " + ")
        let totalGrams = items.reduce(0) { $0 + $1.quantityGrams }
        let totalCalories = items.reduce(0) { $0 + $1.caloriesKcal }
        let totalProtein = items.reduce(0) { $0 + $1.proteinGrams }
        let totalCarbs = items.reduce(0) { $0 + $1.carbsGrams }
        let totalFat = items.reduce(0) { $0 + $1.fatGrams }
        let overall = ScanResult.DetectedItem(
            name: overallName.isEmpty ? L("Posiłek") : overallName,
            quantityGrams: totalGrams,
            caloriesKcal: totalCalories,
            proteinGrams: totalProtein,
            carbsGrams: totalCarbs,
            fatGrams: totalFat,
            confidence: items.map(\.confidence).max() ?? 0.45
        )
        return MealTextAnalysis(
            overall: overall,
            items: items,
            suggestedMealType: mealType,
            confidence: overall.confidence,
            rawAINotes: L("Local text analysis fallback")
        )
    }

    private static func detectedItem(from item: FoodItem) -> ScanResult.DetectedItem {
        ScanResult.DetectedItem(
            id: item.id,
            name: item.name,
            quantityGrams: item.quantityGrams,
            caloriesKcal: item.caloriesKcal,
            proteinGrams: item.proteinGrams,
            carbsGrams: item.carbsGrams,
            fatGrams: item.fatGrams,
            confidence: item.confidence ?? 0.45
        )
    }

    private func enrichAndCache(_ analysis: MealTextAnalysis) async -> MealTextAnalysis {
        let catalog = await currentCatalog()
        let items = await analysis.items.asyncMap { item in
            let resolved = resolve(item: item, catalog: catalog)
            if !resolved.matchedCatalog {
                await cacheAIItemIfPossible(resolved.item, catalog: catalog)
            }
            return resolved.item
        }
        let overallResolved = resolve(item: analysis.overall, catalog: catalog).item
        let overall: ScanResult.DetectedItem
        if analysis.overall.caloriesKcal > 0 || items.isEmpty {
            overall = overallResolved
        } else {
            overall = Self.sum(items: items, fallbackName: analysis.overall.name, confidence: analysis.confidence)
        }
        return MealTextAnalysis(
            overall: overall,
            items: items,
            suggestedMealType: analysis.suggestedMealType,
            confidence: analysis.confidence,
            rawAINotes: analysis.rawAINotes
        )
    }

    private func resolve(
        item: ScanResult.DetectedItem, catalog: [Food]
    ) -> (item: ScanResult.DetectedItem, matchedCatalog: Bool) {
        guard let food = catalog.first(where: { FoodNameNormalizer.isMatch(query: item.name, food: $0) }) else {
            return (item, false)
        }
        let factor = max(item.quantityGrams, 0) / 100
        var resolved = item
        if resolved.caloriesKcal <= 0 {
            resolved.caloriesKcal = food.caloriesKcalPer100g * factor
        }
        if resolved.proteinGrams <= 0 {
            resolved.proteinGrams = food.proteinGramsPer100g * factor
        }
        if resolved.carbsGrams <= 0 {
            resolved.carbsGrams = food.carbsGramsPer100g * factor
        }
        if resolved.fatGrams <= 0 {
            resolved.fatGrams = food.fatGramsPer100g * factor
        }
        resolved.confidence = max(resolved.confidence, 0.82)
        return (resolved, true)
    }

    private func resolve(item: FoodItem, catalog: [Food]) -> (item: FoodItem, matchedCatalog: Bool) {
        guard let food = catalog.first(where: { FoodNameNormalizer.isMatch(query: item.name, food: $0) }) else {
            return (item, false)
        }
        let factor = max(item.quantityGrams, 0) / 100
        item.catalogFoodID = food.id
        if item.caloriesKcal <= 0 {
            item.caloriesKcal = food.caloriesKcalPer100g * factor
        }
        if item.proteinGrams <= 0 {
            item.proteinGrams = food.proteinGramsPer100g * factor
        }
        if item.carbsGrams <= 0 {
            item.carbsGrams = food.carbsGramsPer100g * factor
        }
        if item.fatGrams <= 0 {
            item.fatGrams = food.fatGramsPer100g * factor
        }
        item.confidence = max(item.confidence ?? 0, 0.82)
        return (item, true)
    }

    private func merge(original: FoodItem, ai: ScanResult.DetectedItem) -> FoodItem {
        let factor = ai.quantityGrams > 0 ? original.quantityGrams / ai.quantityGrams : 1
        if original.caloriesKcal <= 0 {
            original.caloriesKcal = ai.caloriesKcal * factor
        }
        if original.proteinGrams <= 0 {
            original.proteinGrams = ai.proteinGrams * factor
        }
        if original.carbsGrams <= 0 {
            original.carbsGrams = ai.carbsGrams * factor
        }
        if original.fatGrams <= 0 {
            original.fatGrams = ai.fatGrams * factor
        }
        original.confidence = max(original.confidence ?? 0, ai.confidence)
        return original
    }

    private func needsNutrition(_ item: FoodItem) -> Bool {
        item.caloriesKcal <= 0 || item.proteinGrams <= 0 || item.carbsGrams <= 0 || item.fatGrams <= 0
    }

    private func bestAIItem(
        for original: FoodItem,
        in aiItems: [ScanResult.DetectedItem],
        usedIndexes: Set<Int>
    ) -> (index: Int, item: ScanResult.DetectedItem)? {
        let originalKey = FoodNameNormalizer.key(for: original.name)
        if let exact = aiItems.enumerated().first(where: { index, item in
            !usedIndexes.contains(index) && FoodNameNormalizer.key(for: item.name) == originalKey
        }) {
            return (exact.offset, exact.element)
        }
        if let fuzzy = aiItems.enumerated().first(where: { index, item in
            let key = FoodNameNormalizer.key(for: item.name)
            return !usedIndexes.contains(index) && (key.contains(originalKey) || originalKey.contains(key))
        }) {
            return (fuzzy.offset, fuzzy.element)
        }
        guard let fallback = aiItems.enumerated().first(where: { !usedIndexes.contains($0.offset) }) else {
            return nil
        }
        return (fallback.offset, fallback.element)
    }

    private func cacheAIItemIfPossible(_ item: ScanResult.DetectedItem, catalog: [Food]) async {
        guard item.quantityGrams > 0,
            item.caloriesKcal > 0,
            item.proteinGrams >= 0,
            item.carbsGrams >= 0,
            item.fatGrams >= 0,
            !catalog.contains(where: { FoodNameNormalizer.isMatch(query: item.name, food: $0) })
        else { return }

        let factor = 100 / item.quantityGrams
        let food = Food(
            remoteID: "ai:\(FoodNameNormalizer.key(for: item.name))",
            name: item.name,
            category: .general,
            caloriesKcalPer100g: item.caloriesKcal * factor,
            proteinGramsPer100g: item.proteinGrams * factor,
            carbsGramsPer100g: item.carbsGrams * factor,
            fatGramsPer100g: item.fatGrams * factor,
            defaultPortionGrams: item.quantityGrams,
            verified: false
        )
        food.localizationsJSON = Self.defaultLocalizationsJSON(for: item.name)
        do {
            _ = try await foodCatalog?.createAIInferred(food)
        } catch {
            Logger.persistence.error("AI food cache insert failed: \(String(describing: error))")
        }
    }

    private func currentCatalog() async -> [Food] {
        if let foodCatalog, let foods = try? await foodCatalog.all() {
            return foods
        }
        return catalogSnapshot
    }

    private static func sum(
        items: [ScanResult.DetectedItem],
        fallbackName: String,
        confidence: Double
    ) -> ScanResult.DetectedItem {
        ScanResult.DetectedItem(
            name: fallbackName.isEmpty ? items.map(\.name).joined(separator: " + ") : fallbackName,
            quantityGrams: items.reduce(0) { $0 + $1.quantityGrams },
            caloriesKcal: items.reduce(0) { $0 + $1.caloriesKcal },
            proteinGrams: items.reduce(0) { $0 + $1.proteinGrams },
            carbsGrams: items.reduce(0) { $0 + $1.carbsGrams },
            fatGrams: items.reduce(0) { $0 + $1.fatGrams },
            confidence: confidence
        )
    }

    private static func defaultLocalizationsJSON(for name: String) -> String? {
        let map = Dictionary(uniqueKeysWithValues: ["pl", "en", "uk", "ru", "es"].map { ($0, name) })
        guard let data = try? JSONEncoder().encode(map) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

extension Array {
    fileprivate func asyncMap<T>(_ transform: (Element) async -> T) async -> [T] {
        var values: [T] = []
        values.reserveCapacity(count)
        for element in self {
            let value = await transform(element)
            values.append(value)
        }
        return values
    }
}

private struct Request: Encodable, Sendable {
    var text: String
    var mealTypeHint: String
    var locale: String
    var quotaKind: String
}

private struct Response: Decodable, Sendable {
    var overall: Item
    var items: [Item]
    var suggestedMealType: String
    var confidence: Double
    var rawAINotes: String?

    func toDomain(fallbackMealType: MealType) -> MealTextAnalysis {
        MealTextAnalysis(
            overall: overall.toDomain(),
            items: items.map { $0.toDomain() },
            suggestedMealType: MealType(rawValue: suggestedMealType) ?? fallbackMealType,
            confidence: confidence,
            rawAINotes: rawAINotes
        )
    }

    struct Item: Decodable, Sendable {
        var name: String
        var quantityGrams: Double
        var caloriesKcal: Double
        var proteinGrams: Double
        var carbsGrams: Double
        var fatGrams: Double
        var confidence: Double

        func toDomain() -> ScanResult.DetectedItem {
            ScanResult.DetectedItem(
                name: name,
                quantityGrams: quantityGrams,
                caloriesKcal: caloriesKcal,
                proteinGrams: proteinGrams,
                carbsGrams: carbsGrams,
                fatGrams: fatGrams,
                confidence: confidence
            )
        }
    }
}
