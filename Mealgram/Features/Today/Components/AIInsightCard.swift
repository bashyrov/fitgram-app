import SwiftUI

/// Soft, conversational insight bubble from "Ola" the coach. Real
/// generation lands in Phase 3 — for now this carries a static-ish message
/// derived from the current totals so the surface is exercised end-to-end.
struct AIInsightCard: View {
    let consumed: Double
    let goal: Int
    let proteinGrams: Double
    let proteinGoal: Int

    var body: some View {
        Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primary)
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ola")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(message)
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var message: LocalizedStringKey {
        let calorieRatio = goal > 0 ? consumed / Double(goal) : 0
        let proteinRatio = proteinGoal > 0 ? proteinGrams / Double(proteinGoal) : 0
        if consumed == 0 {
            return "Dzień dopiero się zaczyna. Co dziś planujesz? Mogę pomóc."
        }
        if calorieRatio < 0.5 {
            return "Idziesz spokojnie. Zostaw miejsce na pełnowartościowy obiad."
        }
        if proteinRatio < 0.4 {
            return "Wartościowy moment, żeby dorzucić trochę białka — strączki, jajka, twaróg."
        }
        if calorieRatio < 0.9 {
            return "Wszystko na kursie. Nie zapomnij o wodzie."
        }
        return "Już prawie cel dzisiejszy. Może lekka przekąska zamiast pełnej porcji?"
    }
}
