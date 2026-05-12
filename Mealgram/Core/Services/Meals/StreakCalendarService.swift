import Foundation
import SwiftData

/// Returns a calendar-month grid (Mon-Sun rows) for any month, with
/// each day flagged "logged" if there was at least one MealEntry that
/// day. Powers the Profile streak-history sheet.
@MainActor
final class StreakCalendarService {
    private let container: ModelContainer
    private let calendar: Calendar

    init(container: ModelContainer, calendar: Calendar = StreakCalendarService.mondayFirst()) {
        self.container = container
        self.calendar = calendar
    }

    static func mondayFirst() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    func snapshot(month containing: Date) -> StreakCalendar.Snapshot {
        let monthStart = startOfMonth(containing: containing)
        guard let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return StreakCalendar.Snapshot(monthStart: monthStart, weeks: [])
        }
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: #Predicate {
                $0.consumedAt >= monthStart && $0.consumedAt < monthEnd
            }
        )
        let meals = (try? context.fetch(descriptor)) ?? []
        let loggedDays = Set(meals.map { calendar.startOfDay(for: $0.consumedAt) })

        return StreakCalendar.Snapshot(
            monthStart: monthStart,
            weeks: weeks(in: monthStart, end: monthEnd, loggedDays: loggedDays)
        )
    }

    private func startOfMonth(containing date: Date) -> Date {
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    private func weeks(in monthStart: Date, end: Date, loggedDays: Set<Date>) -> [StreakCalendar.Week] {
        var weeks: [StreakCalendar.Week] = []
        var currentDay = monthStart
        var currentWeek = StreakCalendar.Week(days: [])

        // Pad leading cells so the first row aligns to Monday.
        let leading = leadingPadding(for: monthStart)
        currentWeek.days = Array(repeating: StreakCalendar.Day.placeholder, count: leading)

        while currentDay < end {
            let isToday = calendar.isDateInToday(currentDay)
            let logged = loggedDays.contains(currentDay)
            currentWeek.days.append(
                .init(
                    date: currentDay,
                    dayOfMonth: calendar.component(.day, from: currentDay),
                    isLogged: logged,
                    isToday: isToday
                )
            )
            if currentWeek.days.count == 7 {
                weeks.append(currentWeek)
                currentWeek = StreakCalendar.Week(days: [])
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: currentDay) else { break }
            currentDay = next
        }
        // Trailing padding for the final row.
        while !currentWeek.days.isEmpty && currentWeek.days.count < 7 {
            currentWeek.days.append(.placeholder)
        }
        if !currentWeek.days.isEmpty { weeks.append(currentWeek) }
        return weeks
    }

    private func leadingPadding(for monthStart: Date) -> Int {
        // Calendar.weekday returns Sunday=1...Saturday=7. For Mon-first
        // grids: Monday → 0 padding, Tuesday → 1, ..., Sunday → 6.
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday + 5) % 7
    }
}

enum StreakCalendar {
    struct Day: Equatable, Sendable, Identifiable {
        let date: Date
        let dayOfMonth: Int
        let isLogged: Bool
        let isToday: Bool

        var isPlaceholder: Bool { dayOfMonth == 0 }
        var id: Date { date }

        static let placeholder = Day(
            date: .distantPast,
            dayOfMonth: 0,
            isLogged: false,
            isToday: false
        )
    }

    struct Week: Equatable, Sendable {
        var days: [Day]
    }

    struct Snapshot: Equatable, Sendable {
        let monthStart: Date
        let weeks: [Week]
    }
}
