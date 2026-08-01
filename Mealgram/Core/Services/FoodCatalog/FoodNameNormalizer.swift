import Foundation

enum FoodNameNormalizer {
    static func key(for text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9а-яіїєґąćęłńóśźż]+"#, with: " ", options: .regularExpression)
            .split(separator: " ")
            .joined(separator: " ")
    }

    static func isMatch(query: String, food: Food) -> Bool {
        let normalizedQuery = key(for: query)
        guard !normalizedQuery.isEmpty else { return false }
        return food.allSearchableNames.contains { candidate in
            let normalizedCandidate = key(for: candidate)
            return normalizedCandidate == normalizedQuery
                || normalizedCandidate.contains(normalizedQuery)
                || normalizedQuery.contains(normalizedCandidate)
        }
    }
}
