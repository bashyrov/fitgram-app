import Foundation

/// Pure-function Mifflin-St Jeor calculator. Given the user's profile,
/// returns suggested daily kcal + macro grams. Used during onboarding
/// to pre-fill the targets the user can then tweak — no medical advice,
/// just the same formula every nutrition app ships.
struct GoalCalculator {
    struct Input: Equatable, Sendable {
        var heightCm: Int
        var weightKg: Double
        var age: Int
        var biologicalSex: BiologicalSex
        var activityLevel: ActivityLevel
        var goal: GoalKind
    }

    struct Output: Equatable, Sendable {
        var dailyCalorieGoalKcal: Int
        var proteinGoalGrams: Int
        var carbsGoalGrams: Int
        var fatGoalGrams: Int
    }

    /// Returns nil when any required input is missing or non-physiological
    /// (e.g. age 0). Callers fall back to the default goals in that case.
    static func calculate(from input: Input) -> Output? {
        guard input.heightCm > 0, input.weightKg > 0, input.age > 0 else { return nil }
        let bmr = mifflinStJeorBMR(input: input)
        let tdee = bmr * activityMultiplier(for: input.activityLevel)
        let adjusted = goalAdjustment(tdee: tdee, goal: input.goal)
        // Macro split: 25% protein / 50% carbs / 25% fat — standard
        // moderate-carb baseline. Tweakable later via Profile.
        let proteinKcal = adjusted * 0.25
        let carbsKcal = adjusted * 0.50
        let fatKcal = adjusted * 0.25
        return Output(
            dailyCalorieGoalKcal: roundedToTen(adjusted),
            proteinGoalGrams: Int((proteinKcal / 4).rounded()),
            carbsGoalGrams: Int((carbsKcal / 4).rounded()),
            fatGoalGrams: Int((fatKcal / 9).rounded())
        )
    }

    static func mifflinStJeorBMR(input: Input) -> Double {
        let base = 10 * input.weightKg + 6.25 * Double(input.heightCm) - 5 * Double(input.age)
        switch input.biologicalSex {
        case .male: return base + 5
        case .female: return base - 161
        case .undisclosed: return base - 78  // midpoint of the two
        }
    }

    static func activityMultiplier(for level: ActivityLevel) -> Double {
        switch level {
        case .sedentary: return 1.2
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.9
        }
    }

    static func goalAdjustment(tdee: Double, goal: GoalKind) -> Double {
        switch goal {
        case .lose: return tdee - 500  // ~0.5 kg / week deficit
        case .maintain: return tdee
        case .gain: return tdee + 300  // gentler surplus to avoid fat gain
        }
    }

    private static func roundedToTen(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}
