import Foundation

/// Pure-function nutrition-label parser. Given the OCR text of a Polish
/// food package, pulls out the standard "Wartości odżywcze / 100 g"
/// block — energy in kcal, plus protein / carb / fat grams. Returns nil
/// when at least the kcal figure can't be located (everything else is
/// degenerate without it).
enum NutritionLabelParser {
    struct Output: Equatable, Sendable {
        let kcalPer100g: Double
        let proteinGramsPer100g: Double
        let carbsGramsPer100g: Double
        let fatGramsPer100g: Double
    }

    static func parse(_ text: String) -> Output? {
        let normalized = text.lowercased()
        guard let kcal = match(normalized, patterns: kcalPatterns) else { return nil }
        let protein = match(normalized, patterns: proteinPatterns) ?? 0
        let carbs = match(normalized, patterns: carbPatterns) ?? 0
        let fat = match(normalized, patterns: fatPatterns) ?? 0
        return Output(
            kcalPer100g: kcal,
            proteinGramsPer100g: protein,
            carbsGramsPer100g: carbs,
            fatGramsPer100g: fat
        )
    }

    // MARK: - Patterns

    /// Common Polish phrasings: "wartość energetyczna 250 kcal",
    /// "energia 250 kcal", "wartość energetyczna: 1045 kj / 250 kcal".
    /// Captures the kcal figure (not kJ).
    private static let kcalPatterns = [
        #"wartość\s+energetyczna[^\d]*(\d+(?:[\.,]\d+)?)\s*kcal"#,
        #"energia[^\d]*(\d+(?:[\.,]\d+)?)\s*kcal"#,
        #"(\d+(?:[\.,]\d+)?)\s*kcal"#,
    ]
    private static let proteinPatterns = [
        #"białko[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
        #"protein[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
    ]
    private static let carbPatterns = [
        #"węglowodany[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
        #"weglowodany[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
        #"carbohydrate[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
    ]
    private static let fatPatterns = [
        #"tłuszcz[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
        #"tluszcz[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
        #"fat[^\d]*(\d+(?:[\.,]\d+)?)\s*g"#,
    ]

    private static func match(_ text: String, patterns: [String]) -> Double? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
            else { continue }
            let nsRange = NSRange(text.startIndex..., in: text)
            guard let result = regex.firstMatch(in: text, options: [], range: nsRange),
                result.numberOfRanges >= 2,
                let captureRange = Range(result.range(at: 1), in: text)
            else { continue }
            let numberString = text[captureRange].replacingOccurrences(of: ",", with: ".")
            if let value = Double(numberString) {
                return value
            }
        }
        return nil
    }
}
