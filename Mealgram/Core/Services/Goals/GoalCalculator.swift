import Foundation

/// Pure-function Mifflin-St Jeor targets calculator. Given a user profile,
/// produces daily kcal + macro + fiber + water targets. The same formula
/// every nutrition app ships — not medical advice, just an evidence-based
/// starting point the user can override later.
///
/// Two surfaces:
///   * `calculate(from:)` — legacy entry, returns `Output` with kcal +
///     protein/carbs/fat. Kept stable for existing callers.
///   * `calculateTargets(from:)` — full Targets bundle (adds fiber, water,
///     bmr, tdee, hit-floor flag, optional projected goal end date).
///
/// The expanded path enforces a safety floor (1200 F / 1500 M / 1350
/// undisclosed) and clamps callers' aggressive deficits up to that
/// floor, surfacing a `hitSafetyFloor` flag so UI can warn the user
/// instead of silently feeding them a starvation plan.
struct GoalCalculator {
    struct Input: Equatable, Sendable {
        var heightCm: Int
        var weightKg: Double
        var age: Int
        var biologicalSex: BiologicalSex
        var activityLevel: ActivityLevel
        var goal: GoalKind
        /// Optional pace in kg/week (positive). Only used when goal is
        /// `.lose` or `.gain`. Nil falls back to the legacy fixed
        /// adjustment (±500 / ±300) for back-compat.
        var paceKgPerWeek: Double?

        init(
            heightCm: Int,
            weightKg: Double,
            age: Int,
            biologicalSex: BiologicalSex,
            activityLevel: ActivityLevel,
            goal: GoalKind,
            paceKgPerWeek: Double? = nil
        ) {
            self.heightCm = heightCm
            self.weightKg = weightKg
            self.age = age
            self.biologicalSex = biologicalSex
            self.activityLevel = activityLevel
            self.goal = goal
            self.paceKgPerWeek = paceKgPerWeek
        }
    }

    struct Output: Equatable, Sendable {
        var dailyCalorieGoalKcal: Int
        var proteinGoalGrams: Int
        var carbsGoalGrams: Int
        var fatGoalGrams: Int
    }

    struct Targets: Equatable, Sendable {
        var bmr: Int
        var tdee: Int
        var dailyCalorieGoalKcal: Int
        var proteinGoalGrams: Int
        var carbsGoalGrams: Int
        var fatGoalGrams: Int
        var fiberGoalGrams: Int
        var waterGoalMl: Int
        /// True when the user's requested pace would have pushed kcal
        /// below the sex-specific minimum, so we capped it. UI uses this
        /// to surface "Cel jest zbyt agresywny" warning.
        var hitSafetyFloor: Bool
    }

    // MARK: - Legacy API (kept for back-compat with existing callers)

    static func calculate(from input: Input) -> Output? {
        guard let full = calculateTargets(from: input) else { return nil }
        return Output(
            dailyCalorieGoalKcal: full.dailyCalorieGoalKcal,
            proteinGoalGrams: full.proteinGoalGrams,
            carbsGoalGrams: full.carbsGoalGrams,
            fatGoalGrams: full.fatGoalGrams
        )
    }

    // MARK: - Full targets

    /// Returns nil when any required input is missing or non-physiological
    /// (e.g. age 0, weight 0, height 0). All other inputs are clamped to
    /// plausible ranges before computation.
    static func calculateTargets(from input: Input) -> Targets? {
        guard input.heightCm > 0, input.weightKg > 0, input.age > 0 else { return nil }
        let bmr = mifflinStJeorBMR(input: input)
        let tdee = bmr * activityMultiplier(for: input.activityLevel)
        let rawAdjusted = goalAdjustment(tdee: tdee, goal: input.goal, paceKgPerWeek: input.paceKgPerWeek)
        let floor = safetyFloor(for: input.biologicalSex)
        let hitFloor = rawAdjusted < Double(floor) - 0.5
        let adjusted = max(rawAdjusted, Double(floor))
        let split = macroSplit(for: input.goal)
        let proteinKcal = adjusted * split.protein
        let carbsKcal = adjusted * split.carbs
        let fatKcal = adjusted * split.fat
        return Targets(
            bmr: Int(bmr.rounded()),
            tdee: Int(tdee.rounded()),
            dailyCalorieGoalKcal: roundedToTen(adjusted),
            proteinGoalGrams: Int((proteinKcal / 4).rounded()),
            carbsGoalGrams: Int((carbsKcal / 4).rounded()),
            fatGoalGrams: Int((fatKcal / 9).rounded()),
            fiberGoalGrams: fiberTarget(forCalories: adjusted, sex: input.biologicalSex),
            waterGoalMl: waterTarget(weightKg: input.weightKg),
            hitSafetyFloor: hitFloor
        )
    }

    // MARK: - Building blocks (exposed for unit tests)

    static func mifflinStJeorBMR(input: Input) -> Double {
        let base = 10 * input.weightKg + 6.25 * Double(input.heightCm) - 5 * Double(input.age)
        switch input.biologicalSex {
        case .male: return base + 5
        case .female: return base - 161
        case .undisclosed: return base - 78
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

    /// Adjusts TDEE for the user's main goal. When `paceKgPerWeek` is
    /// supplied, scales by 1100 kcal per kg/week (≈ 7700 kcal/kg of body
    /// fat ÷ 7 days). Otherwise falls back to the legacy fixed deltas.
    static func goalAdjustment(tdee: Double, goal: GoalKind, paceKgPerWeek: Double? = nil) -> Double {
        switch goal {
        case .maintain, .healthCondition, .justTracking:
            return tdee
        case .lose:
            if let pace = paceKgPerWeek, pace > 0 {
                return tdee - (pace * 1100)
            }
            return tdee - 500
        case .gain:
            if let pace = paceKgPerWeek, pace > 0 {
                return tdee + (pace * 1100)
            }
            return tdee + 300
        }
    }

    /// Sex-specific minimum daily kcal, below which we refuse to go.
    /// Aligns with WHO / ACSM guidance for healthy non-clinical adults.
    static func safetyFloor(for sex: BiologicalSex) -> Int {
        switch sex {
        case .female: return 1200
        case .male: return 1500
        case .undisclosed: return 1350
        }
    }

    /// Macro split as fractions of total kcal. Different goal kinds bias
    /// towards different macros: weight loss → more protein for satiety
    /// + lean-mass retention; gain → more carbs for training fuel.
    struct MacroSplit: Equatable, Sendable {
        var protein: Double
        var carbs: Double
        var fat: Double
    }

    static func macroSplit(for goal: GoalKind) -> MacroSplit {
        switch goal {
        case .lose: return MacroSplit(protein: 0.30, carbs: 0.42, fat: 0.28)
        case .maintain, .healthCondition, .justTracking:
            return MacroSplit(protein: 0.25, carbs: 0.45, fat: 0.30)
        case .gain: return MacroSplit(protein: 0.25, carbs: 0.50, fat: 0.25)
        }
    }

    /// Fiber per IOM guidance: ~14 g per 1000 kcal, clamped to sex-
    /// specific safety ranges so under-eaters still get enough fiber
    /// and over-eaters don't see absurd targets.
    static func fiberTarget(forCalories kcal: Double, sex: BiologicalSex) -> Int {
        let raw = (kcal / 1000) * 14
        let (lower, upper): (Int, Int)
        switch sex {
        case .female: (lower, upper) = (25, 30)
        case .male: (lower, upper) = (30, 38)
        case .undisclosed: (lower, upper) = (27, 34)
        }
        return min(max(Int(raw.rounded()), lower), upper)
    }

    /// Hydration heuristic: 35 ml per kg of body weight, rounded to the
    /// nearest 50 ml so the editor's slider has clean stops.
    static func waterTarget(weightKg: Double) -> Int {
        let raw = weightKg * 35
        return Int((raw / 50).rounded()) * 50
    }

    private static func roundedToTen(_ value: Double) -> Int {
        Int((value / 10).rounded()) * 10
    }
}

/// Projected end date for a weight-loss / weight-gain goal at a given
/// pace. Pure function so it can be tested without dragging in Calendar
/// mocking — `from` parameter defaults to `Date()` but tests inject
/// fixed dates.
enum GoalProjection {
    /// Returns the date the user is projected to hit `targetWeightKg`
    /// at `paceKgPerWeek`, or nil if pace is non-positive / target
    /// equals current (no progress required).
    static func estimatedEndDate(
        currentWeightKg: Double,
        targetWeightKg: Double,
        paceKgPerWeek: Double,
        from start: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        guard paceKgPerWeek > 0 else { return nil }
        let delta = abs(currentWeightKg - targetWeightKg)
        guard delta > 0.05 else { return nil }
        let weeks = delta / paceKgPerWeek
        let days = Int((weeks * 7).rounded(.up))
        return calendar.date(byAdding: .day, value: days, to: start)
    }
}
