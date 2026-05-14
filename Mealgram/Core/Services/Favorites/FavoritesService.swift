import Foundation
import OSLog
import SwiftData

/// CRUD + re-add for `FavoriteMeal`. Quota check lives at the call
/// site (UI gates against `Entitlements.canUseFavorites`); this service
/// is dumb storage so tests can verify the data path without dragging
/// in entitlements wiring.
@MainActor
protocol FavoritesServing: AnyObject {
    func favorites(for userID: String) throws -> [FavoriteMeal]
    func add(_ favorite: FavoriteMeal) throws
    func remove(id: UUID) throws
    func recordUse(id: UUID) throws

    /// Looks up an existing favourite by name + catalog id pair (or just
    /// name if catalogFoodID is nil). Used by FavoriteButton so a re-tap
    /// removes instead of duplicating.
    func find(
        userID: String,
        name: String,
        catalogFoodID: UUID?
    ) throws -> FavoriteMeal?

    /// Trims the user's favourites to at most `cap` rows, keeping the
    /// oldest entries (lowest `createdAt`). No-op when cap is nil
    /// (premium) or when count is already under the cap.
    func trimToCap(userID: String, cap: Int?) throws
}

@MainActor
final class FavoritesService: FavoritesServing {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func favorites(for userID: String) throws -> [FavoriteMeal] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FavoriteMeal>(
            predicate: #Predicate { $0.userRemoteID == userID },
            sortBy: [
                SortDescriptor(\FavoriteMeal.useCount, order: .reverse),
                SortDescriptor(\FavoriteMeal.lastUsedAt, order: .reverse),
                SortDescriptor(\FavoriteMeal.createdAt, order: .reverse),
            ]
        )
        return try context.fetch(descriptor)
    }

    func add(_ favorite: FavoriteMeal) throws {
        let context = ModelContext(container)
        context.insert(favorite)
        try context.save()
        Logger.persistence.notice("Favorite added: \(favorite.name, privacy: .public)")
    }

    func remove(id: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FavoriteMeal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let row = try context.fetch(descriptor).first else { return }
        context.delete(row)
        try context.save()
    }

    func recordUse(id: UUID) throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<FavoriteMeal>(
            predicate: #Predicate { $0.id == id }
        )
        guard let row = try context.fetch(descriptor).first else { return }
        row.useCount += 1
        row.lastUsedAt = Date()
        try context.save()
    }

    func find(
        userID: String,
        name: String,
        catalogFoodID: UUID?
    ) throws -> FavoriteMeal? {
        let context = ModelContext(container)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let descriptor = FetchDescriptor<FavoriteMeal>(
            predicate: #Predicate { $0.userRemoteID == userID && $0.name == trimmed }
        )
        let matches = try context.fetch(descriptor)
        // When catalogFoodID is set, prefer the exact pair; otherwise
        // return the first name match.
        if let catalogID = catalogFoodID {
            return matches.first(where: { $0.catalogFoodID == catalogID }) ?? matches.first
        }
        return matches.first
    }

    func trimToCap(userID: String, cap: Int?) throws {
        guard let cap, cap >= 0 else { return }
        let context = ModelContext(container)
        // Sort ascending by createdAt so "first N" = the oldest N.
        let descriptor = FetchDescriptor<FavoriteMeal>(
            predicate: #Predicate { $0.userRemoteID == userID },
            sortBy: [SortDescriptor(\FavoriteMeal.createdAt, order: .forward)]
        )
        let rows = try context.fetch(descriptor)
        guard rows.count > cap else { return }
        for stale in rows.suffix(rows.count - cap) {
            context.delete(stale)
        }
        try context.save()
        Logger.persistence.notice(
            "FavoritesService trimmed \(rows.count - cap) rows on downgrade"
        )
    }
}
