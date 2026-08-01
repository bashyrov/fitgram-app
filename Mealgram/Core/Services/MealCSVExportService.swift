import Foundation
import OSLog
import SwiftData

/// Companion to `DataExportService` — produces a flat CSV of all meal
/// entries, one row per `FoodItem` so spreadsheets can pivot freely.
/// Used by the "Eksport CSV" action on Profile.
@MainActor
final class MealCSVExportService {
    private let container: ModelContainer
    private let calendar: Calendar
    private let now: () -> Date

    init(
        container: ModelContainer,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init
    ) {
        self.container = container
        self.calendar = calendar
        self.now = now
    }

    /// Renders the meal log to a CSV file in tmp/exports/ and returns
    /// the URL. Headers in PL so the Excel-using user has labels they'll
    /// recognise; numeric values use a dot decimal separator regardless of
    /// locale (Excel-pl auto-detects). `from`/`to` filter to a date range
    /// — pass nil for either bound to leave that end open.
    func export(from: Date? = nil, to: Date? = nil) throws -> URL {
        let csv = try buildCSV(from: from, to: to)
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let stamp = Self.fileTimestamp.string(from: now())
        let fileURL = directory.appending(path: "mealgram-meals-\(stamp).csv")
        try Data(csv.utf8).write(to: fileURL, options: [.atomic])
        Logger.persistence.notice("Exported CSV to \(fileURL.lastPathComponent, privacy: .public)")
        return fileURL
    }

    /// Public for tests — string form of the CSV without the file write.
    func buildCSV(from: Date? = nil, to: Date? = nil) throws -> String {
        let context = ModelContext(container)
        let lowerBound = from.map(calendar.startOfDay(for:))
        let upperBound = to.flatMap { date in
            let dayStart = calendar.startOfDay(for: date)
            return calendar.date(byAdding: .day, value: 1, to: dayStart)
        }
        let predicate: Predicate<MealEntry>?
        switch (lowerBound, upperBound) {
        case (let low?, let high?):
            predicate = #Predicate { $0.consumedAt >= low && $0.consumedAt < high }
        case (let low?, nil):
            predicate = #Predicate { $0.consumedAt >= low }
        case (nil, let high?):
            predicate = #Predicate { $0.consumedAt < high }
        case (nil, nil):
            predicate = nil
        }
        let descriptor = FetchDescriptor<MealEntry>(
            predicate: predicate,
            sortBy: [SortDescriptor(\MealEntry.consumedAt)]
        )
        let meals = try context.fetch(descriptor)
        var rows: [String] = [Self.header]
        for meal in meals {
            for item in meal.items {
                rows.append(row(meal: meal, item: item))
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Helpers

    // CSV column headers are kept in English so the exported file stays
    // portable across locales and parseable by spreadsheet tools.
    private static let header = [
        "date", "time", "type", "source", "item",
        "grams", "portion_multiplier", "kcal", "protein_g", "carbs_g", "fat_g",
        "rating", "tags",
    ].joined(separator: ",")

    private func row(meal: MealEntry, item: FoodItem) -> String {
        let date = Self.dateFormatter.string(from: meal.consumedAt)
        let time = Self.timeFormatter.string(from: meal.consumedAt)
        let scaledKcal = item.caloriesKcal * meal.portionMultiplier
        let scaledProtein = item.proteinGrams * meal.portionMultiplier
        let scaledCarbs = item.carbsGrams * meal.portionMultiplier
        let scaledFat = item.fatGrams * meal.portionMultiplier
        let ratingCell = meal.rating.map(String.init) ?? ""
        let tagsCell = Self.escape(meal.tags.joined(separator: " "))
        return [
            date,
            time,
            meal.mealType.rawValue,
            meal.source.rawValue,
            Self.escape(item.name),
            Self.format(item.quantityGrams),
            Self.format(meal.portionMultiplier),
            Self.format(scaledKcal),
            Self.format(scaledProtein),
            Self.format(scaledCarbs),
            Self.format(scaledFat),
            ratingCell,
            tagsCell,
        ].joined(separator: ",")
    }

    /// RFC 4180 quoting — wrap in quotes when the value contains a comma,
    /// quote, or newline. Inner quotes get doubled.
    static func escape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if !needsQuoting { return value }
        let doubled = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(doubled)\""
    }

    static func format(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        return String(format: "%.2f", value)
    }

    private static var dateFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    
}
    private static var timeFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    
}
    private static var fileTimestamp: DateFormatter {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    
}
}
