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
