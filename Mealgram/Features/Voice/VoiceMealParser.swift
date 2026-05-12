import Foundation

/// Best-effort Polish voice-transcript → `FoodItem` parser. Pure function;
/// no network, no LLM. The heuristics handle the patterns we see most:
///
///   "schabowy 200 gram"          → name "schabowy", quantity 200 g
///   "owsianka 300 kalorii"        → name "owsianka", kcal 300 (qty 100 g)
///   "kanapka 250 g 400 kcal"      → name "kanapka", qty 250 g, kcal 400
///   "jabłko"                       → name "jabłko", qty 100 g (default)
///
/// When the catalog is supplied (optional), the parser also tries to
/// resolve the name to a Food row so the saved item carries proper per-
/// 100g macros. When no LLM is available this is the easy win.
struct VoiceMealParser {
    let catalog: [Food]

    init(catalog: [Food] = []) {
        self.catalog = catalog
    }

    /// Always produces at least one item, even for unparseable transcripts.
    /// Returns the catalog-match flag so callers know whether to trust
    /// the macro numbers.
    func parse(_ transcript: String) -> FoodItem {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return Self.placeholder(name: "") }

        let lower = cleaned.lowercased()
        let extractedKcal = Self.extractCalories(from: lower)
        let extractedGrams = Self.extractGrams(from: lower)

        // Strip the patterns we matched so the remaining tokens form the
        // ingredient name.
        var name = lower
        for pattern in Self.allPatterns {
            name = name.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        name =
            name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        if name.isEmpty { name = cleaned }

        // Try to match the residual name against the catalog. Same
        // approach as the recipe estimator: exact lowercase first, then
        // shared-token (≥ 4-char) overlap.
        let match = Self.bestMatch(for: name, in: catalog)
        let grams = extractedGrams ?? match?.defaultPortionGrams ?? 100

        if let match {
            let factor = grams / 100.0
            return FoodItem(
                name: match.name,
                quantityGrams: grams,
                caloriesKcal: extractedKcal ?? match.caloriesKcalPer100g * factor,
                proteinGrams: match.proteinGramsPer100g * factor,
                carbsGrams: match.carbsGramsPer100g * factor,
                fatGrams: match.fatGramsPer100g * factor,
                fiberGrams: match.fiberGramsPer100g.map { $0 * factor },
                catalogFoodID: match.id,
                confidence: 0.7
            )
        }

        return FoodItem(
            name: name.capitalized,
            quantityGrams: grams,
            caloriesKcal: extractedKcal ?? 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            confidence: extractedKcal != nil ? 0.6 : 0.3
        )
    }

    static func placeholder(name: String) -> FoodItem {
        FoodItem(
            name: name.isEmpty ? String(localized: "Posiłek") : name,
            quantityGrams: 100,
            caloriesKcal: 0
        )
    }

    // MARK: - Extraction

    /// All regexes the parser strips when computing the name. Order
    /// matters: kcal before plain numbers, gram patterns before bare
    /// digit suffixes.
    private static let allPatterns = [
        #"(\d+(?:[\.,]\d+)?)\s*(kalorii|kalorie|kcal|kal)\b"#,
        #"(\d+(?:[\.,]\d+)?)\s*(gram(?:ów|y)?|grama|gr|g)\b"#,
    ]

    static func extractCalories(from text: String) -> Double? {
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(kalorii|kalorie|kcal|kal)\b"#
        return extractDouble(from: text, pattern: pattern)
    }

    static func extractGrams(from text: String) -> Double? {
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(gram(?:ów|y)?|grama|gr|g)\b"#
        return extractDouble(from: text, pattern: pattern)
    }

    private static func extractDouble(from text: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let nsRange = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
            match.numberOfRanges >= 2,
            let captureRange = Range(match.range(at: 1), in: text)
        else { return nil }
        let numberString = text[captureRange].replacingOccurrences(of: ",", with: ".")
        return Double(numberString)
    }

    // MARK: - Catalog matching

    static func bestMatch(for name: String, in catalog: [Food]) -> Food? {
        let cleaned = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        if let exact = catalog.first(where: { $0.name.lowercased() == cleaned }) {
            return exact
        }
        let tokens = Self.tokenize(cleaned)
        guard !tokens.isEmpty else { return nil }
        var bestScore = 0
        var best: Food?
        for food in catalog {
            let foodTokens = Self.tokenize(food.name.lowercased())
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
}
