import Foundation

/// Domain enums shared across SwiftData models. All raw values are stable
/// strings — never integers — so future migrations don't get tied to source
/// order.

enum MealType: String, Codable, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner
    case snack
}

enum MealSource: String, Codable, CaseIterable, Sendable {
    case photoScan = "photo_scan"
    case recipe
    case quickDatabase = "quick_db"
    case voice
    case barcode
    case manual
}

enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female
    case male
    case undisclosed
}

enum ActivityLevel: String, Codable, CaseIterable, Sendable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive = "very_active"
}

enum GoalKind: String, Codable, CaseIterable, Sendable {
    case lose
    case maintain
    case gain
    /// "Konkretny cel zdrowotny" — user has a medical / clinician-led
    /// goal that doesn't map to weight change. Math falls back to TDEE
    /// (maintain), but the surface labels differently.
    case healthCondition = "health_condition"
    /// "No goal, just tracking" — user just wants to log without any
    /// energy target. Math falls back to TDEE.
    case justTracking = "just_tracking"
}

extension GoalKind {
    /// True when this goal involves a directional weight change with a
    /// pace + target weight. Used by Onboarding to decide whether to
    /// show the pace/target screen, and by the calculator to know
    /// whether to apply a deficit/surplus.
    var requiresPaceAndTarget: Bool {
        self == .lose || self == .gain
    }
}

enum FoodCategory: String, Codable, CaseIterable, Sendable {
    case general
    case homemade
    case restaurant
    case fastFood = "fast_food"
    case packaged
    case beverage
    case snack
    case produce
    case bakery
    case dairy
    case meat
    case seafood
    case sweets
    case grain
}

enum ReferenceObjectKind: String, Codable, CaseIterable, Sendable {
    case creditCard = "credit_card"
    case eatingHand = "eating_hand"
    case fork
    case generic
}
