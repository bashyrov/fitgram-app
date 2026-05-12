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

    /// Renders the full meal log to a CSV file in tmp/exports/ and returns
    /// the URL. Headers in PL so the Excel-using user has labels they'll
    /// recognise; numeric values use a dot decimal separator regardless of
    /// locale (Excel-pl auto-detects).
    func export() throws -> URL {
        let csv = try buildCSV()
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
    func buildCSV() throws -> String {
        let context = ModelContext(container)
        let meals = try context.fetch(
            FetchDescriptor<MealEntry>(
                sortBy: [SortDescriptor(\MealEntry.consumedAt)]
            )
        )
        var rows: [String] = [Self.header]
        for meal in meals {
            for item in meal.items {
                rows.append(row(meal: meal, item: item))
            }
        }
        return rows.joined(separator: "\n")
    }

    // MARK: - Helpers

    private static let header = [
        "data", "godzina", "typ", "źródło", "pozycja",
        "gramy", "porcja_multiplier", "kcal", "białko_g", "węgle_g", "tłuszcz_g",
    ].joined(separator: ",")

    private func row(meal: MealEntry, item: FoodItem) -> String {
        let date = Self.dateFormatter.string(from: meal.consumedAt)
        let time = Self.timeFormatter.string(from: meal.consumedAt)
        let scaledKcal = item.caloriesKcal * meal.portionMultiplier
        let scaledProtein = item.proteinGrams * meal.portionMultiplier
        let scaledCarbs = item.carbsGrams * meal.portionMultiplier
        let scaledFat = item.fatGrams * meal.portionMultiplier
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
