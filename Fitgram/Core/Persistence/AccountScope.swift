import Foundation
import OSLog
import SwiftData

/// The account whose meals and recipes the app shows.
///
/// Meals and recipes live only in the on-device store, so two accounts
/// signed in one after the other on the same iPhone share that store.
/// Every meal and recipe is stamped with its owner's id and every read
/// filters on `currentUserID`, so a second account never sees the first
/// account's history.
enum AccountScope {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var storedUserID = ""

    /// Remote id of the signed-in account, or "" when signed out (which
    /// matches no stamped row).
    static var currentUserID: String {
        lock.lock()
        defer { lock.unlock() }
        return storedUserID
    }

    static func activate(_ userID: String?) {
        lock.lock()
        storedUserID = userID ?? ""
        lock.unlock()
    }

    /// Hands rows saved before meals, recipes and custom foods carried an owner to the
    /// account signed in now. Runs on every sign-in; once the legacy rows
    /// are claimed there is nothing left to match.
    @MainActor
    static func claimUnownedRows(for userID: String, in container: ModelContainer) {
        guard !userID.isEmpty else { return }
        let context = ModelContext(container)
        let unowned = String()
        do {
            let meals = try context.fetch(
                FetchDescriptor<MealEntry>(predicate: #Predicate { $0.userRemoteID == unowned }))
            let recipes = try context.fetch(
                FetchDescriptor<Recipe>(predicate: #Predicate { $0.userRemoteID == unowned }))
            // "My kitchen" foods: not verified catalogue rows, not AI cache.
            let customFoods = try context.fetch(
                FetchDescriptor<Food>(
                    predicate: #Predicate { $0.ownerRemoteID == unowned && !$0.verified && $0.remoteID == nil }))
            guard !meals.isEmpty || !recipes.isEmpty || !customFoods.isEmpty else { return }
            meals.forEach { $0.userRemoteID = userID }
            recipes.forEach { $0.userRemoteID = userID }
            customFoods.forEach { $0.ownerRemoteID = userID }
            try context.save()
            Logger.persistence.notice("Claimed \(meals.count) meals and \(recipes.count) recipes for the account")
        } catch {
            Logger.persistence.error("Claiming unowned rows failed: \(String(describing: error))")
        }
    }
}
