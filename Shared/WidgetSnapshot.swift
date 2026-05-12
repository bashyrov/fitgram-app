import Foundation

/// Tiny value type the app writes to a shared UserDefaults so the widget
/// can render without spinning up SwiftData itself. Codable so it
/// round-trips through a single Data blob — keeps the store API one
/// read / one write.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    var streakLength: Int
    var calorieGoalKcal: Int
    var caloriesConsumedKcal: Int
    var lastMealName: String
    var updatedAt: Date

    var caloriesRemainingKcal: Int {
        max(0, calorieGoalKcal - caloriesConsumedKcal)
    }

    var streakLabel: String {
        streakLength == 1 ? "dzień z rzędu" : "dni z rzędu"
    }

    static let placeholder = WidgetSnapshot(
        streakLength: 0,
        calorieGoalKcal: 0,
        caloriesConsumedKcal: 0,
        lastMealName: "",
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

/// Reads + writes the snapshot from the shared App Group UserDefaults.
/// When the app group isn't entitled (simulator without team-id setup,
/// fresh checkout), falls back to standard defaults so the widget can
/// still render a valid placeholder.
struct WidgetSnapshotStore {
    static let shared = WidgetSnapshotStore()
    static let appGroupID = "group.app.mealgram.shared"
    static let key = "mealgram.widget.snapshot.v1"

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: Self.key)
    }

    func load() -> WidgetSnapshot? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}
