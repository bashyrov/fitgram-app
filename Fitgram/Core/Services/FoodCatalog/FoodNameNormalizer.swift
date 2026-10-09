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

/// Normalised names of a catalogue snapshot, built once and reused. Matching
/// a meal item against ~3k foods with `isMatch` re-decoded every food's
/// translations and re-ran the regex for each name — tens of thousands of
/// operations on the main actor per saved item, which froze "Dodaj do
/// dziennika" after a detailed photo scan.
@MainActor
final class FoodMatchIndex {
    static let shared = FoodMatchIndex()

    private struct Entry {
        let food: Food
        let keys: [String]
    }

    private var entries: [Entry] = []
    /// Cheap identity of the snapshot: size plus its first and last food.
    private struct Signature: Equatable {
        var count = 0
        var first: ObjectIdentifier?
        var last: ObjectIdentifier?
    }

    private var signature = Signature()

    /// First food whose name (in any language) matches `query` the same way
    /// `FoodNameNormalizer.isMatch` does.
    func firstMatch(for query: String, in catalog: [Food]) -> Food? {
        let normalizedQuery = FoodNameNormalizer.key(for: query)
        guard !normalizedQuery.isEmpty else { return nil }
        rebuildIfNeeded(for: catalog)
        return entries.first { entry in
            entry.keys.contains { candidate in
                candidate == normalizedQuery
                    || candidate.contains(normalizedQuery)
                    || normalizedQuery.contains(candidate)
            }
        }?.food
    }

    private func rebuildIfNeeded(for catalog: [Food]) {
        let next = Signature(
            count: catalog.count,
            first: catalog.first.map(ObjectIdentifier.init),
            last: catalog.last.map(ObjectIdentifier.init)
        )
        guard next != signature else { return }
        signature = next
        entries = catalog.map { food in
            Entry(
                food: food,
                keys: food.allSearchableNames.map(FoodNameNormalizer.key(for:)).filter { !$0.isEmpty }
            )
        }
    }
}
