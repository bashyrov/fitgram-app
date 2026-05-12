import Foundation
import SwiftData

/// Global search across the user's meal history. Matches by FoodItem
/// name (case-insensitive contains) and returns the parent MealEntry
/// rows sorted newest-first.
@MainActor
final class MealSearchService {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func search(query: String, limit: Int = 100) throws -> [MealEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let context = ModelContext(container)
        // Fetch the full meal stream sorted desc — the @Relationship to
        // FoodItem is in-memory after fetch so filtering happens in
        // Swift land. The catalog stays small (months of meals,
        // typically < 5000 entries) so this is fast enough not to need
        // SQL FTS yet.
        let descriptor = FetchDescriptor<MealEntry>(
            sortBy: [SortDescriptor(\MealEntry.consumedAt, order: .reverse)]
        )
        let all = try context.fetch(descriptor)
        let matches = all.filter { entry in
            entry.items.contains { item in
                item.name.localizedCaseInsensitiveContains(trimmed)
            }
        }
        return Array(matches.prefix(limit))
    }
}
