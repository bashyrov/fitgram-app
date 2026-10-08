import Foundation

/// Single source of truth for free-tier access.
enum FreeTierLimits {
    /// Hidden abuse guard for every AI-backed request, including premium.
    /// This is not shown as a product limit; it protects AI cost from runaway
    /// loops, scripted calls, or accidental repeated taps.
    static let aiRequestsSafetyCapPerDay = 30

    /// One weekly AI pool for free users, shared by photo scans, voice/text
    /// meals, meal refreshes and single-product lookups (Mon–Sun, local time).
    /// Everything non-AI — barcode, Quick DB, manual entry — stays unlimited.
    /// `nil` means unlimited.
    static let aiActionsPerWeek: Int? = 10
    // Free Ola Chef uses the local catalog and never calls AI.
    static let olaChefRequestsPerDay: Int? = nil

    static let barcodeScansPerDay: Int? = nil
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
