import Foundation

/// Single source of truth for what the free tier allows. Premium gets
/// the no-cap version of every line. Constants live here (not scattered
/// across feature views) so changing the strategy is a single-file diff.
///
/// Numbers picked per spec 2026-05-14 — generous enough to be useful,
/// tight enough that engaged users see a paywall in week 1-2.
enum FreeTierLimits {
    /// Per-week quotas (ISO weeks, Monday-anchored). UsageMeter handles
    /// the rollover.
    static let photoScansPerWeek: Int = 3
    static let barcodeScansPerWeek: Int = 3
    static let voiceEntriesPerWeek: Int = 3
    static let coachWeeklyDebriefsPerWeek: Int = 1

    /// Soft caps — saving a new item past the cap raises the paywall.
    static let activeCustomGoals: Int = 1
    static let savedRecipes: Int = 5
    static let friendsCount: Int = 3
    static let favorites: Int = 0  // free tier can't favourite at all

    /// History cutoff — meals + weight entries older than this are
    /// readable but charts only render the trailing window.
    static let historyDays: Int = 30

    /// Export formats free users can pick. JSON is the GDPR-portability
    /// minimum; CSV + ZIP are premium polish.
    static let allowedExportFormats: Set<ExportFormat> = [.json]

    /// Premium-only switches. UI either hides or shows-with-lock.
    static let canUseFavorites: Bool = false
    static let canChangeTheme: Bool = false
    static let canUseICloudSync: Bool = false
}

enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case json
    case csv
    case zip
}
