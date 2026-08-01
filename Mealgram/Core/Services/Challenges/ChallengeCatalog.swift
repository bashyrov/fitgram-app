import Foundation

/// Static catalogue of weekly challenges. Hand-tuned for the Mealgram
/// rhythm — three "consistency" challenges (logged days / breakfast /
/// calorie target), three "variety + skill" (protein / variety / recipe
/// cooks). All run in parallel; the user doesn't pick.
enum ChallengeCatalog {
    static let all: [Challenge] = [
        Challenge(
            id: "log-every-day",
            title: L("Codzienny rytm"),
            body: L("Zapisz przynajmniej jeden posiłek każdego dnia w tym tygodniu."),
            systemImage: "calendar",
            rule: .loggedDays(target: 7)
        ),
        Challenge(
            id: "protein-5-days",
            title: L("Protein expert"),
            body: L("Trafiaj w cel białka co najmniej w 5 dni."),
            systemImage: "fork.knife",
            rule: .proteinDaysHit(target: 5)
        ),
        Challenge(
            id: "calorie-5-days",
            title: L("Stabilny tydzień"),
            body: L("5 dni w pasie kalorii (±15 %) — bez skrajności."),
            systemImage: "scalemass",
            rule: .calorieDaysOnTarget(target: 5)
        ),
        Challenge(
            id: "breakfast-5-days",
            title: L("Mistrz śniadań"),
            body: L("Zaczynaj dzień posiłkiem — 5 śniadań w tygodniu."),
            systemImage: "sun.max.fill",
            rule: .breakfastDays(target: 5)
        ),
        Challenge(
            id: "variety-15",
            title: L("Kolorowy talerz"),
            body: L("Spróbuj 15 różnych produktów w tym tygodniu."),
            systemImage: "leaf.fill",
            rule: .distinctFoods(target: 15)
        ),
        Challenge(
            id: "recipe-cooks-2",
            title: L("Domowy kucharz"),
            body: L("Ugotuj swój przepis przynajmniej 2 razy."),
            systemImage: "book.fill",
            rule: .recipeCooks(target: 2)
        ),
    ]
}
