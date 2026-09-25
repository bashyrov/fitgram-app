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

    /// Multi-item entry point — splits the transcript on Polish
    /// connectives ("i", "oraz", "plus") and commas, parses each segment
    /// independently and drops empty fragments. Empty / non-food speech
    /// returns no items so the UI can ask the user to try again instead
    /// of inventing a generic meal.
    func parseMultiple(_ transcript: String) -> [FoodItem] {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.hasRecognizableFoodText(cleaned) else { return [] }
        let segments = Self.split(cleaned)
        let items = segments.map { parse($0) }
            .filter(Self.isUsableParsedItem)
        return items.isEmpty ? [parse(cleaned)].filter(Self.isUsableParsedItem) : items
    }

    /// Splits `"jajka 2 i tost z masłem oraz kawa"` into
    /// `["jajka 2", "tost z masłem", "kawa"]`. Lowercase, then matches
    /// `\bi\b`, `\boraz\b`, `\bplus\b`, and commas as separators. Decimal
    /// commas stay inside numbers, so "0,5 kg ryżu" remains one segment.
    static func split(_ transcript: String) -> [String] {
        let lower = transcript.lowercased()
        let pattern = #"\s*((?<!\d),(?!\d)|\bi\b|\boraz\b|\bplus\b)\s*"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return [transcript]
        }
        let nsRange = NSRange(lower.startIndex..., in: lower)
        var pieces: [String] = []
        var cursor = lower.startIndex
        regex.enumerateMatches(in: lower, options: [], range: nsRange) { match, _, _ in
            guard let match,
                let range = Range(match.range, in: lower)
            else { return }
            let segment = lower[cursor..<range.lowerBound]
            let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { pieces.append(trimmed) }
            cursor = range.upperBound
        }
        let tail = lower[cursor..<lower.endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { pieces.append(tail) }
        return pieces.isEmpty ? [transcript] : pieces
    }

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
            .filter { !$0.isEmpty && !Self.leadingMealWords.contains($0) }
            .joined(separator: " ")
        if name.isEmpty { name = cleaned }
        name = Self.aliases[name] ?? name

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
            name: name.isEmpty ? L("Posiłek") : name,
            quantityGrams: 100,
            caloriesKcal: 0
        )
    }

    static func hasRecognizableFoodText(_ transcript: String) -> Bool {
        let cleaned = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        var residual = cleaned.lowercased()
        for pattern in allPatterns {
            residual = residual.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }

        let tokens =
            residual
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)
            .filter { token in
                let folded = fold(token)
                return folded.count >= 2 && !leadingMealWords.contains(folded) && !fillerWords.contains(folded)
            }
        return !tokens.isEmpty
    }

    static func isUsableParsedItem(_ item: FoodItem) -> Bool {
        let folded = fold(item.name.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !folded.isEmpty, folded != fold(L("Posiłek")) else { return false }
        return hasRecognizableFoodText(item.name)
    }

    // MARK: - Extraction

    /// All regexes the parser strips when computing the name. Order
    /// matters: kcal before plain numbers, gram patterns before bare
    /// digit suffixes.
    private static let allPatterns = [
        #"(\d+(?:[\.,]\d+)?)\s*(kalorii|kalorie|kcal|kal)\b"#,
        #"(\d+(?:[\.,]\d+)?)\s*(kilogram(?:ów|y)?|kilograma|kg)\b"#,
        #"(\d+(?:[\.,]\d+)?)\s*(gram(?:ów|y)?|grama|gr|g)\b"#,
    ]

    static func extractCalories(from text: String) -> Double? {
        let pattern = #"(\d+(?:[\.,]\d+)?)\s*(kalorii|kalorie|kcal|kal)\b"#
        return extractDouble(from: text, pattern: pattern)
    }

    static func extractGrams(from text: String) -> Double? {
        let gramPattern = #"(\d+(?:[\.,]\d+)?)\s*(gram(?:ów|y)?|grama|gr|g)\b"#
        if let grams = extractDouble(from: text, pattern: gramPattern) {
            return grams
        }
        let kilogramPattern = #"(\d+(?:[\.,]\d+)?)\s*(kilogram(?:ów|y)?|kilograma|kg)\b"#
        return extractDouble(from: text, pattern: kilogramPattern).map { $0 * 1000 }
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
        let cleanedRaw = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = Self.aliases[cleanedRaw] ?? cleanedRaw
        guard !cleaned.isEmpty else { return nil }
        if let exact = catalog.first(where: { $0.name.lowercased() == cleaned }) {
            return exact
        }
        let folded = Self.fold(cleaned)
        if let foldedExact = catalog.first(where: { Self.fold($0.name.lowercased()) == folded }) {
            return foldedExact
        }
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
            Self.fold(text).split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 4 }
        )
    }

    private static let leadingMealWords: Set<String> = [
        "zjadlem", "zjadłem", "zjadlam", "zjadłam", "zjadl", "zjadł", "zjadla", "zjadła",
        "jadlem", "jadłem", "jadlam", "jadłam", "snie", "śnię", "zjem", "mam",
    ]

    private static let fillerWords: Set<String> = [
        "posilek", "posiłek", "jedzenie", "danie", "cos", "coś", "nic", "test", "halo", "hej",
    ]

    private static let aliases: [String: String] = [
        "ryzu": "ryż",
        "ryżu": "ryż",
        "sera": "ser",
        "seru": "ser",
        "kurczaka": "kurczak",
        "piersi z kurczaka": "pierś z kurczaka",
    ]

    private static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "pl_PL"))
    }
}
