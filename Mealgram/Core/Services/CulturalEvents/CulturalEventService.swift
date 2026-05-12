import Foundation

/// Computes the nearest-future Polish cultural event for a given reference
/// date. Pure (no I/O), so it's trivial to unit-test deterministically.
struct CulturalEventService {
    let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Returns the upcoming occurrence of any catalog event within
    /// `lookahead` days (inclusive). `nil` when nothing is close enough.
    func upcoming(
        from reference: Date = Date(),
        lookahead: Int = 7
    ) -> Upcoming? {
        let referenceDay = calendar.startOfDay(for: reference)
        let candidates = CulturalEvent.catalog.flatMap { event -> [Upcoming] in
            occurrences(of: event, near: referenceDay).map { date in
                let days = calendar.dateComponents([.day], from: referenceDay, to: date).day ?? 0
                return Upcoming(event: event, date: date, daysAway: days)
            }
        }
        let candidates2 = candidates.filter { $0.daysAway >= 0 && $0.daysAway <= lookahead }
        return candidates2.min(by: { $0.daysAway < $1.daysAway })
    }

    /// All future occurrences within the next 18 months — useful for
    /// "Coming up" lists in Profile / Calendar UIs.
    func calendar(from reference: Date = Date(), within months: Int = 18) -> [Upcoming] {
        let referenceDay = calendar.startOfDay(for: reference)
        guard let horizon = calendar.date(byAdding: .month, value: months, to: referenceDay) else {
            return []
        }
        return CulturalEvent.catalog
            .flatMap { event in
                occurrences(of: event, near: referenceDay).map { date in
                    let days = self.calendar.dateComponents([.day], from: referenceDay, to: date).day ?? 0
                    return Upcoming(event: event, date: date, daysAway: days)
                }
            }
            .filter { $0.date >= referenceDay && $0.date <= horizon }
            .sorted(by: { $0.date < $1.date })
    }

    // MARK: - Per-event occurrence resolution

    private func occurrences(of event: CulturalEvent, near reference: Date) -> [Date] {
        let referenceYear = calendar.component(.year, from: reference)
        let years = [referenceYear, referenceYear + 1]
        return years.compactMap { year in
            switch event.id {
            case CulturalEvent.wigilia.id:
                return fixedDate(year: year, month: 12, day: 24)
            case CulturalEvent.walentynki.id:
                return fixedDate(year: year, month: 2, day: 14)
            case CulturalEvent.andrzejki.id:
                return fixedDate(year: year, month: 11, day: 30)
            case CulturalEvent.sylwester.id:
                return fixedDate(year: year, month: 12, day: 31)
            case CulturalEvent.tlustyCzwartek.id:
                guard let easter = easterSunday(year: year) else { return nil }
                return calendar.date(byAdding: .day, value: -52, to: easter)
            case CulturalEvent.wielkanoc.id:
                return easterSunday(year: year)
            default:
                return nil
            }
        }
    }

    private func fixedDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = day
        return components.date.map { calendar.startOfDay(for: $0) }
    }

    /// Anonymous Gregorian algorithm (a.k.a. Meeus/Jones/Butcher). Valid
    /// for Gregorian dates 1583+. Single-letter variables match the
    /// canonical formula in literature; lint exception is local.
    // swiftlint:disable identifier_name
    func easterSunday(year: Int) -> Date? {
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return fixedDate(year: year, month: month, day: day)
    }
    // swiftlint:enable identifier_name

    struct Upcoming: Equatable, Sendable {
        let event: CulturalEvent
        let date: Date
        let daysAway: Int

        var isToday: Bool { daysAway == 0 }
    }
}
