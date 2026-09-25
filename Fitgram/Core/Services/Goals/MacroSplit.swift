import Foundation

/// One of the named macro distributions a user can pick to seed their
/// protein / carbs / fat goals from a calorie target. Each percent is
/// 0-1; sums always equal 1.0 within float tolerance.
struct MacroSplit: Hashable, Sendable {
    struct Grams: Equatable, Sendable {
        let protein: Int
        let carbs: Int
        let fat: Int
    }

    let id: String
    let label: String
    let proteinShare: Double
    let carbsShare: Double
    let fatShare: Double
    let preset: DietMacroPreset?

    /// Convert the split into protein/carbs/fat grams for a given daily
    /// calorie target. Protein + carbs cost 4 kcal/g, fat 9 kcal/g.
    func grams(forCalories kcal: Int) -> Grams {
        let total = Double(max(0, kcal))
        let protein = (total * proteinShare / 4).rounded()
        let carbs = (total * carbsShare / 4).rounded()
        let fat = (total * fatShare / 9).rounded()
        return Grams(protein: Int(protein), carbs: Int(carbs), fat: Int(fat))
    }
}

extension MacroSplit {
    static var presets: [MacroSplit] {
        DietMacroPreset.allCases.map { preset in
            MacroSplit(
                id: preset.rawValue,
                label: "\(preset.title) \(preset.splitLabel)",
                proteinShare: preset.proteinShare,
                carbsShare: preset.carbsShare,
                fatShare: preset.fatShare,
                preset: preset
            )
        }
    }
}
