import Charts
import SwiftUI

/// Pie chart of today's macro split (by kcal-equivalent grams) + three
/// thin horizontal progress bars below. Pie only renders once there's
/// some intake — otherwise it'd look like an empty wheel.
struct MacroDistributionCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    let proteinGoal: Int
    let carbsGoal: Int
    let fatGoal: Int

    private struct Slice: Identifiable {
        let id = UUID()
        let name: String
        let kcal: Double
        let color: Color
    }

    private var slices: [Slice] {
        [
            Slice(name: "Protein", kcal: protein * 4, color: Tokens.Palette.primary),
            Slice(name: "Carbs", kcal: carbs * 4, color: Tokens.Palette.warning),
            Slice(name: "Fat", kcal: fat * 9, color: Tokens.Palette.accent),
        ]
    }

    private var hasIntake: Bool {
        protein + carbs + fat > 0
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(alignment: .top) {
                    Text("Makro")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if hasIntake {
                        pieChart
                    }
                }
                macroRow(
                    label: "Protein",
                    grams: protein,
                    goal: proteinGoal,
                    color: Tokens.Palette.primary
                )
                macroRow(
                    label: "Carbs",
                    grams: carbs,
                    goal: carbsGoal,
                    color: Tokens.Palette.warning
                )
                macroRow(
                    label: "Fat",
                    grams: fat,
                    goal: fatGoal,
                    color: Tokens.Palette.accent
                )
            }
        }
    }

    private var pieChart: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("kcal", slice.kcal),
                innerRadius: .ratio(0.55),
                angularInset: 1
            )
            .foregroundStyle(slice.color)
            .cornerRadius(2)
        }
        .frame(width: 64, height: 64)
        .accessibilityLabel(Text("Wykres kołowy podziału makro"))
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
                Text(String.localizedStringWithFormat(L("%lld / %lld g"), Int(grams), goal))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(String.localizedStringWithFormat(L("%lld z %lld gramów"), Int(grams), goal)))
    }
}
