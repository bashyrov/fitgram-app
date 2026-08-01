import Foundation

/// Single source of truth for free-tier access.
enum FreeTierLimits {
    /// Hidden abuse guard for every AI-backed request, including premium.
    /// This is not shown as a product limit; it protects AI cost from runaway
    /// loops, scripted calls, or accidental repeated taps.
    static let aiRequestsSafetyCapPerDay = 60

    /// Shared daily AI budget for free users. `nil` means unlimited.
    static let aiLoggedMealsPerDay: Int? = 3
    static let aiMealRefreshesPerDay: Int? = 3
    static let aiProductLookupsPerDay: Int? = 2
    static let olaChefRequestsPerDay: Int? = 1

    static let photoScansPerWeek: Int? = aiLoggedMealsPerDay
    static let barcodeScansPerWeek: Int? = nil
    static let voiceEntriesPerWeek: Int? = aiLoggedMealsPerDay
    static let coachWeeklyDebriefsPerWeek: Int? = 0

    static let activeCustomGoals: Int? = nil
    static let savedRecipes: Int? = 5
    static let friendsCount: Int? = nil
    static let favorites: Int? = nil

    static let historyDays: Int? = nil

    static let allowedExportFormats: Set<ExportFormat> = [.json, .csv, .zip]

    static let canUseFavorites: Bool = true
    static let canChangeTheme: Bool = true
    static let canUseICloudSync: Bool = true
    static let canUseOlaAdvice: Bool = false
}

enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case json
    case csv
    case zip
}
