import Foundation

/// A single hand-curated nutrition / weight / training factoid surfaced
/// on the "Porady od Oli" screen. One per calendar day is highlighted as
/// the "ciekawostka dnia"; the full catalog is browsable from the
/// secondary segment.
///
/// Bodies are deliberately written in Polish, ~3-5 sentences each, in a
/// "smart friend over coffee" tone. They are flagged as PL-only this
/// pass — translations land in a follow-up bulk pass.
struct NutritionFact: Identifiable, Sendable, Equatable, Hashable {
    /// Stable string identifier so we can persist "seen" facts later
    /// without depending on array index.
    let id: String
    let category: Category
    /// Single emoji glyph leading the card.
    let icon: String
    /// Short headline — also serves as a row label in the catalogue.
    let title: String
    /// 3-5 sentence body. PL only this pass.
    let body: String
    /// Optional source/citation footer. Keep it short — "WHO 2024",
    /// "EFSA", "IŻŻ". Nil means "internal editorial".
    let source: String?

    init(
        id: String,
        category: Category,
        icon: String,
        title: String,
        body: String,
        source: String? = nil
    ) {
        self.id = id
        self.category = category
        self.icon = icon
        self.title = title
        self.body = body
        self.source = source
    }

    enum Category: String, CaseIterable, Sendable, Identifiable {
        case calories
        case weightLoss
        case weightGain
        case protein
        case carbs
        case fats
        case fiber
        case hydration
        case metabolism
        case training
        case psychology
        case polishCuisine

        var id: String { rawValue }

        /// Human-readable Polish chip label (also used in the segmented
        /// filter strip). All UI-facing labels go through `String(localized:)`
        /// at call site — this is just the canonical key.
        var displayKey: String {
            switch self {
            case .calories: return "Kalorie"
            case .weightLoss: return "Odchudzanie"
            case .weightGain: return "Masa"
            case .protein: return "Białko"
            case .carbs: return "Węglowodany"
            case .fats: return "Tłuszcze"
            case .fiber: return "Błonnik"
            case .hydration: return "Nawodnienie"
            case .metabolism: return "Metabolizm"
            case .training: return "Trening"
            case .psychology: return "Psychologia"
            case .polishCuisine: return "Kuchnia PL"
            }
        }
    }
}
