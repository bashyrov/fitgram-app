import SwiftUI

/// Three thin horizontal progress bars — protein, carbs, fat — with the
/// gram value next to each. Kept low-contrast so it doesn't compete with
/// the hero calorie card.
struct MacroDistributionCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Makro")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                macroRow(
                    label: "Białko",
                    grams: protein,
                    goal: proteinGoal,
                    color: Tokens.Palette.primary
                )
                macroRow(
                    label: "Węgle",
                    grams: carbs,
                    goal: carbsGoal,
                    color: Tokens.Palette.warning
                )
                macroRow(
                    label: "Tłuszcz",
                    grams: fat,
                    goal: fatGoal,
                    color: Tokens.Palette.accent
                )
            }
        }
    }

    private func macroRow(
        label: LocalizedStringKey,
        grams: Double,
        goal: Int,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("\(Int(grams)) / \(goal) g")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            GeometryReader { proxy in
                let progress = goal > 0 ? min(1.0, grams / Double(goal)) : 0
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * progress)
                        .animation(Tokens.Motion.gentle, value: progress)
                }
            }
            .frame(height: 6)
        }
    }
}
