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

    /// Macro totals + goals (grams). Default-zeroed so older payloads
    /// decoded by a fresh build still produce a valid (placeholder)
    /// snapshot without throwing.
    var proteinConsumedGrams: Int = 0
    var proteinGoalGrams: Int = 0
    var carbsConsumedGrams: Int = 0
    var carbsGoalGrams: Int = 0
    var fatConsumedGrams: Int = 0
    var fatGoalGrams: Int = 0

    /// Water tracking (ml). Same default-zero treatment for backwards
    /// compatibility with snapshots written before these fields existed.
    var waterMl: Int = 0
    var waterGoalMl: Int = 0

    /// Today's most recent meals (name + kcal, capped at 6 to keep the
    /// payload tiny). Empty when no meals logged.
    var recentMeals: [MealRow] = []

    struct MealRow: Codable, Equatable, Sendable {
        var name: String
        var kcal: Int
    }

    var caloriesRemainingKcal: Int {
        max(0, calorieGoalKcal - caloriesConsumedKcal)
    }

    var streakLabel: String {
        streakLength == 1 ? "dzień z rzędu" : "dni z rzędu"
    }

    var calorieProgress: Double {
        guard calorieGoalKcal > 0 else { return 0 }
        return min(1.0, Double(caloriesConsumedKcal) / Double(calorieGoalKcal))
    }

    var proteinProgress: Double {
        guard proteinGoalGrams > 0 else { return 0 }
        return min(1.0, Double(proteinConsumedGrams) / Double(proteinGoalGrams))
    }

    var carbsProgress: Double {
        guard carbsGoalGrams > 0 else { return 0 }
        return min(1.0, Double(carbsConsumedGrams) / Double(carbsGoalGrams))
    }

    var fatProgress: Double {
        guard fatGoalGrams > 0 else { return 0 }
        return min(1.0, Double(fatConsumedGrams) / Double(fatGoalGrams))
    }

    var waterProgress: Double {
        guard waterGoalMl > 0 else { return 0 }
        return min(1.0, Double(waterMl) / Double(waterGoalMl))
    }

    static let placeholder = WidgetSnapshot(
        streakLength: 0,
        calorieGoalKcal: 0,
        caloriesConsumedKcal: 0,
        lastMealName: "",
        updatedAt: Date(timeIntervalSince1970: 0)
    )

    /// Pretty preview used by widget Xcode previews. All fields filled so
    /// the design renders fully in the preview canvas.
    static let preview = WidgetSnapshot(
        streakLength: 7,
        calorieGoalKcal: 2100,
        caloriesConsumedKcal: 1340,
        lastMealName: "Owsianka z owocami",
        updatedAt: Date(),
        proteinConsumedGrams: 78,
        proteinGoalGrams: 120,
        carbsConsumedGrams: 160,
        carbsGoalGrams: 240,
        fatConsumedGrams: 45,
        fatGoalGrams: 70,
        waterMl: 1400,
        waterGoalMl: 2500,
        recentMeals: [
            MealRow(name: "Owsianka z owocami", kcal: 420),
            MealRow(name: "Kurczak z ryżem", kcal: 560),
            MealRow(name: "Skyr z miodem", kcal: 180),
            MealRow(name: "Sałatka grecka", kcal: 320),
            MealRow(name: "Twaróg z rzodkiewką", kcal: 220),
            MealRow(name: "Banan", kcal: 90)
        ]
    )
}

/// Reads + writes the snapshot from the shared App Group container.
///
/// Both the app target and the widget extension belong to the
/// `group.app.mealgram.shared` App Group. We write the snapshot as a
/// file inside the group's shared container — that path is the **only**
/// way to reliably share between two processes (UserDefaults via
/// `suiteName:` works too, but suffers cache invalidation lag on the
/// widget side; the file approach is force-reread on every widget
/// refresh).
///
/// When the App Group isn't entitled (e.g. simulator without team-id
/// setup, fresh checkout signing into a personal team) we fall back to
/// `Application Support/` for the writing app and the widget reads its
/// own placeholder — that path can't be shared cross-process but at
/// least the app's own debug views still see live data.
struct WidgetSnapshotStore {
    static let shared = WidgetSnapshotStore()
    static let appGroupID = "group.app.mealgram.shared"
    static let key = "mealgram.widget.snapshot.v1"
    static let fileName = "widget-snapshot.json"

    private let fm = FileManager.default

    private var snapshotURL: URL? {
        if let group = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID) {
            return group.appendingPathComponent(Self.fileName)
        }
        // App-Group fallback: per-process Application Support directory.
        // Cross-process sharing won't work here but at least the writing
        // process can round-trip its own data for debugging.
        return (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ))?.appendingPathComponent(Self.fileName)
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: Self.appGroupID) ?? .standard
    }

    func write(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        // File first (the cross-process channel)…
        if let url = snapshotURL {
            try? data.write(to: url, options: .atomic)
        }
        // …UserDefaults too as a belt-and-braces backup. WidgetKit reads
        // defaults from the suite synchronously which avoids a file-IO
        // hop on cold timeline reloads.
        defaults.set(data, forKey: Self.key)
    }

    func load() -> WidgetSnapshot? {
        // Prefer the file — it's the canonical cross-process source.
        if let url = snapshotURL,
           let data = try? Data(contentsOf: url),
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            return snap
        }
        // UserDefaults fallback.
        if let data = defaults.data(forKey: Self.key),
           let snap = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) {
            return snap
        }
        return nil
    }
}
