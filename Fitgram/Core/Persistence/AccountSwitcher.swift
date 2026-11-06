import Foundation
import OSLog
import SwiftData

extension Notification.Name {
    /// Posted after another account's on-device data became the live one.
    /// Services that cache account data (usage counters, the food catalogue)
    /// reload on it.
    static let fitgramAccountDidChange = Notification.Name("FitgramAccountDidChange")
}

/// Keeps several accounts on one iPhone apart. Meals, recipes and the other
/// SwiftData rows are filtered by owner (`AccountScope`); this type moves
/// the state that cannot be filtered: `UserDefaults` values and the Quick DB
/// pick counters stored on the shared food catalogue.
@MainActor
enum AccountSwitcher {
    static let picksKey = "foodPicks.v1"

    /// Runs on every sign-in, before the UI shows the account.
    static func activate(
        _ userID: String,
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        spotlight: (any RecipeSpotlightIndexing)? = nil
    ) {
        guard !userID.isEmpty else { return }
        let context = ModelContext(container)
        let previous = AccountDefaults.owner(in: defaults)
        if previous != nil, previous != userID {
            defaults.set(exportPicks(in: context), forKey: picksKey)
        }
        if AccountDefaults.switchTo(userID, in: defaults) {
            importPicks(defaults.dictionary(forKey: picksKey) ?? [:], in: context)
            defaults.removeObject(forKey: picksKey)
            Logger.persistence.notice("Switched on-device data to another account")
        }
        AccountScope.claimUnownedRows(for: userID, in: container)
        if let spotlight, previous != userID {
            reindexSpotlight(spotlight, for: userID, in: context)
        }
        NotificationCenter.default.post(name: .fitgramAccountDidChange, object: nil)
    }

    /// Deletes one account's on-device data and leaves every other account
    /// on this iPhone as it was.
    static func deleteAccountData(
        _ userID: String,
        container: ModelContainer,
        defaults: UserDefaults = .standard,
        photoStore: MealPhotoStore? = nil,
        avatarDirectory: URL? = nil,
        syncState: CloudSyncStateStore? = nil
    ) throws {
        guard !userID.isEmpty else { return }
        let context = ModelContext(container)

        let meals = try context.fetch(FetchDescriptor<MealEntry>(predicate: #Predicate { $0.userRemoteID == userID }))
        let users = try context.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.remoteID == userID }))
        let photos = Set(meals.compactMap(\.photoFilename))
        let avatars = users.compactMap(\.avatarFilename)

        meals.forEach(context.delete)
        users.forEach(context.delete)
        try deleteOwnedRows(of: userID, in: context)
        if AccountDefaults.owner(in: defaults) == userID {
            importPicks([:], in: context)
        }
        try context.save()

        let stillUsed = Set(try context.fetch(FetchDescriptor<MealEntry>()).compactMap(\.photoFilename))
        for filename in photos.subtracting(stillUsed) {
            photoStore?.delete(filename: filename)
        }
        if let avatarDirectory {
            for filename in avatars {
                try? FileManager.default.removeItem(at: avatarDirectory.appendingPathComponent(filename))
            }
        }
        AccountDefaults.forget(userID, in: defaults)
        syncState?.remove(userID)
    }

    private static func deleteOwnedRows(of userID: String, in context: ModelContext) throws {
        try delete(#Predicate<Recipe> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<Calibration> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<Streak> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<Achievement> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<WeightEntry> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<CoachInsightLog> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<CoachMemoryNote> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<WaterEntry> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<CustomGoal> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<FavoriteMeal> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<WorkoutEntry> { $0.userRemoteID == userID }, in: context)
        try delete(#Predicate<Food> { $0.ownerRemoteID == userID }, in: context)
    }

    private static func delete<T: PersistentModel>(_ predicate: Predicate<T>, in context: ModelContext) throws {
        try context.fetch(FetchDescriptor<T>(predicate: predicate)).forEach(context.delete)
    }

    // MARK: - Quick DB picks

    /// `[foodID: [pickCount, lastPickedAt seconds]]`, a property-list value.
    private static func exportPicks(in context: ModelContext) -> [String: [Double]] {
        let picked = (try? context.fetch(FetchDescriptor<Food>(predicate: #Predicate { $0.pickCount > 0 }))) ?? []
        var result: [String: [Double]] = [:]
        for food in picked {
            result[food.id.uuidString] = [
                Double(food.pickCount), food.lastPickedAt?.timeIntervalSince1970 ?? 0,
            ]
        }
        return result
    }

    private static func importPicks(_ picks: [String: Any], in context: ModelContext) {
        let touched =
            (try? context.fetch(
                FetchDescriptor<Food>(predicate: #Predicate { $0.pickCount > 0 || $0.lastPickedAt != nil }))) ?? []
        for food in touched {
            food.pickCount = 0
            food.lastPickedAt = nil
        }
        for (key, value) in picks {
            guard let id = UUID(uuidString: key), let numbers = value as? [Double], numbers.count == 2 else {
                continue
            }
            let descriptor = FetchDescriptor<Food>(predicate: #Predicate { $0.id == id })
            guard let food = try? context.fetch(descriptor).first else { continue }
            food.pickCount = Int(numbers[0])
            food.lastPickedAt = numbers[1] > 0 ? Date(timeIntervalSince1970: numbers[1]) : nil
        }
        try? context.save()
    }

    private static func reindexSpotlight(
        _ spotlight: any RecipeSpotlightIndexing, for userID: String, in context: ModelContext
    ) {
        spotlight.removeAll()
        let recipes = (try? context.fetch(FetchDescriptor<Recipe>(predicate: #Predicate { $0.userRemoteID == userID })))
        spotlight.indexAll(recipes ?? [])
    }
}
