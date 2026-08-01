import Foundation
import OSLog

/// Picks one `NutritionFact` per calendar day, deterministically.
///
/// Same date → same fact across launches and processes (no UserDefaults
/// state needed). Date changes → next fact. Index is derived from the
/// ISO date string hashed against the catalog count.
///
/// We use the catalog passed in at init so tests can inject smaller
/// fixtures and verify determinism without touching the production array.
@MainActor
final class DailyFactSelector {
    private static let logger = Logger(subsystem: "app.mealgram", category: "DailyFactSelector")

    private let catalog: [NutritionFact]
    private let calendar: Calendar
    private let now: () -> Date

    init(
        catalog: [NutritionFact] = NutritionFactCatalog.all,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.catalog = catalog
        self.calendar = calendar
        self.now = now
    }

    /// Today's fact, or `nil` if the catalog is empty.
    func factForToday() -> NutritionFact? {
        fact(for: now())
    }

    /// Today's fact inside a specific category. This keeps the daily
    /// highlight aligned with the user's current goal instead of picking
    /// randomly from the whole library.
    func factForToday(in category: NutritionFact.Category) -> NutritionFact? {
        fact(for: now(), in: category)
    }

    /// Visible for tests — fact for any arbitrary date.
    func fact(for date: Date) -> NutritionFact? {
        fact(for: date, in: nil)
    }

    /// Visible for tests — fact for any arbitrary date and optional
    /// category. Falls back to the full catalog when the category has no
    /// entries, so the Today screen never goes blank.
    func fact(for date: Date, in category: NutritionFact.Category?) -> NutritionFact? {
        guard !catalog.isEmpty else {
            Self.logger.error("Empty fact catalog — nothing to pick")
            return nil
        }
        let scoped = category.map { wanted in
            catalog.filter { $0.category == wanted }
        } ?? catalog
        let pool = scoped.isEmpty ? catalog : scoped
        let key = Self.dayKey(for: date, calendar: calendar)
        // Stable FNV-1a 32-bit hash so we don't depend on Swift's
        // randomly seeded String.hashValue (which differs per process).
        let categorySalt = category?.rawValue ?? "all"
        let hash = Self.fnv1a32("\(key).\(categorySalt)")
        let index = Int(hash % UInt32(pool.count))
        return pool[index]
    }

    /// Public so callers (e.g. the "facts" sheet) can derive the same
    /// key for caching or logging. Uses the calendar passed in at init,
    /// so the fact rolls over at the user's local midnight.
    static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    /// Tiny FNV-1a 32-bit. We don't need cryptographic quality — just a
    /// deterministic spread across the catalog.
    private static func fnv1a32(_ string: String) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5
        for byte in string.utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return hash
    }
}
