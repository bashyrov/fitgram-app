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
    static let presets: [MacroSplit] = [
        MacroSplit(
            id: "balanced",
            label: String(localized: "Zbalansowane 25 / 50 / 25"),
            proteinShare: 0.25,
            carbsShare: 0.50,
            fatShare: 0.25
        ),
        MacroSplit(
            id: "highProtein",
            label: String(localized: "Wysoko-białkowe 35 / 35 / 30"),
            proteinShare: 0.35,
            carbsShare: 0.35,
            fatShare: 0.30
        ),
        MacroSplit(
            id: "endurance",
            label: String(localized: "Wytrzymałościowe 20 / 55 / 25"),
            proteinShare: 0.20,
            carbsShare: 0.55,
            fatShare: 0.25
        ),
        MacroSplit(
            id: "lowCarb",
            label: String(localized: "Mniej węgli 30 / 30 / 40"),
            proteinShare: 0.30,
            carbsShare: 0.30,
            fatShare: 0.40
        ),
        MacroSplit(
            id: "keto",
            label: String(localized: "Keto 25 / 5 / 70"),
            proteinShare: 0.25,
            carbsShare: 0.05,
            fatShare: 0.70
        ),
    ]
}
