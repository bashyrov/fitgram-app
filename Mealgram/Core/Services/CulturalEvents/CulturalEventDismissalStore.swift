import Foundation

/// Remembers which Polish cultural event banners the user has dismissed
/// this season. Key is `eventID:yearOfDate` — so "Wigilia 2026" stays
/// hidden the rest of December but next year's Wigilia surfaces fresh.
/// UserDefaults-backed; the data is fully derivable from the catalog so
/// we don't need a SwiftData table.
struct CulturalEventDismissalStore {
    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    func dismiss(_ upcoming: CulturalEventService.Upcoming) {
        var dismissed = stored()
        dismissed.insert(key(for: upcoming))
        defaults.set(Array(dismissed), forKey: Self.storageKey)
    }

    func isDismissed(_ upcoming: CulturalEventService.Upcoming) -> Bool {
        stored().contains(key(for: upcoming))
    }

    func clearAll() {
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func key(for upcoming: CulturalEventService.Upcoming) -> String {
        let year = calendar.component(.year, from: upcoming.date)
        return "\(upcoming.event.id):\(year)"
    }

    private func stored() -> Set<String> {
        Set((defaults.array(forKey: Self.storageKey) as? [String]) ?? [])
    }

    private static let storageKey = "cultural.events.dismissed"
}
