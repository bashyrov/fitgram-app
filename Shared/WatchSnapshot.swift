import Foundation

/// Tiny Codable value sent from iPhone to the Apple Watch companion
/// over `WCSession.updateApplicationContext(_:)`. Intentionally
/// separate from `WidgetSnapshot` — the home-screen widget needs
/// streak / last-meal context, the Watch face only renders three
/// rings + a water button, so we keep the payload minimal.
///
/// Note: kcal + protein consumed are rounded ints (Watch never
/// shows decimals). Water is already an int in the iOS model.
struct WatchSnapshot: Codable, Equatable, Sendable {
    var kcalConsumed: Int
    var kcalGoal: Int
    var proteinConsumed: Int
    var proteinGoal: Int
    var waterMl: Int
    var waterGoalMl: Int
    var updatedAt: Date

    var kcalProgress: Double {
        guard kcalGoal > 0 else { return 0 }
        return min(1.0, Double(kcalConsumed) / Double(kcalGoal))
    }

    var proteinProgress: Double {
        guard proteinGoal > 0 else { return 0 }
        return min(1.0, Double(proteinConsumed) / Double(proteinGoal))
    }

    var waterProgress: Double {
        guard waterGoalMl > 0 else { return 0 }
        return min(1.0, Double(waterMl) / Double(waterGoalMl))
    }

    static let placeholder = WatchSnapshot(
        kcalConsumed: 0,
        kcalGoal: 2100,
        proteinConsumed: 0,
        proteinGoal: 120,
        waterMl: 0,
        waterGoalMl: 2500,
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    static let preview = WatchSnapshot(
        kcalConsumed: 1340,
        kcalGoal: 2100,
        proteinConsumed: 78,
        proteinGoal: 120,
        waterMl: 1400,
        waterGoalMl: 2500,
        updatedAt: Date()
    )
}

/// Wire-format keys for the `sendMessage` callbacks between Watch and
/// phone. Centralised so the two sides never disagree on a string.
enum WatchMessageKey {
    static let action = "action"
    static let addWaterGlass = "addWaterGlass"
}
