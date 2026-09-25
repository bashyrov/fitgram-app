import Foundation

/// A single hand-curated nutrition / weight / training factoid surfaced
/// on the "Porady od Oli" screen. One per calendar day is highlighted as
/// the "ciekawostka dnia"; the full catalog is browsable from the
/// secondary segment.
///
/// Bodies are short, concrete and localized through either
/// Localizable.xcstrings or the generated-catalog `TL(...)` helper.
struct NutritionFact: Identifiable, Sendable, Equatable, Hashable {
    /// Stable string identifier so we can persist "seen" facts later
    /// without depending on array index.
    let id: String
    let category: Category
    /// Single emoji glyph leading the card.
    let icon: String
    /// Short headline — also serves as a row label in the catalogue.
    let title: String
    /// Short body in the current app language.
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
        /// filter strip). Wrapped here with `String(localized:)` so the
        /// keys are extracted into Localizable.xcstrings at build time.
        var displayKey: String {
            switch self {
            case .calories: return L("Kalorie")
            case .weightLoss: return L("Odchudzanie")
            case .weightGain: return L("Masa")
            case .protein: return L("Protein")
            case .carbs: return L("Węglowodany")
            case .fats: return L("Tłuszcze")
            case .fiber: return L("Fiber")
            case .hydration: return L("Nawodnienie")
            case .metabolism: return L("Metabolizm")
            case .training: return L("Trening")
            case .psychology: return L("Psychologia")
            case .polishCuisine: return L("Kuchnia PL")
            }
        }
    }
}
