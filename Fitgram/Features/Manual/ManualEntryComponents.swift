import SwiftUI

/// One editable ingredient in the manual entry's detailed mode.
struct ManualIngredientDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var quantityGrams: Double = 100
    var caloriesKcal: Double = 200
    var proteinGrams: Double = 10
    var carbsGrams: Double = 20
    var fatGrams: Double = 8
}

extension ManualIngredientDraft {
    init(detected item: ScanResult.DetectedItem) {
        self.init(
            name: item.name,
            quantityGrams: item.quantityGrams,
            caloriesKcal: item.caloriesKcal,
            proteinGrams: item.proteinGrams,
            carbsGrams: item.carbsGrams,
            fatGrams: item.fatGrams
        )
    }
}

/// `nrow(label, value, unit)`: 14/800 label on the left, − value + stepper on the right.
/// `symbol` / `tint` are kept for API compatibility; design D shows label + stepper only.
struct ManualNumericRow: View {
    struct Config {
        let symbol: String
        let label: LocalizedStringKey
        let range: ClosedRange<Double>
        let step: Double
        let unit: String
        var tint: Color = Tokens.Palette.primary
    }

    let config: Config
    @Binding var value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(config.label)
                .font(Tokens.Font.manrope(14, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            MonoStepper(value: $value, range: config.range, step: config.step, unit: config.unit)
        }
        .padding(.vertical, 8)
    }
}

/// "Posiłek" card with the meal-type segmented control.
struct ManualMealTypeCard: View {
    @Binding var mealType: MealType

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Posiłek"))
            MonoSegmented(
                selection: $mealType,
                options: [
                    (value: MealType.breakfast, title: L("Breakfast")),
                    (value: MealType.lunch, title: L("Lunch")),
                    (value: MealType.dinner, title: L("Dinner")),
                    (value: MealType.snack, title: L("Snack")),
                ]
            )
            .accessibilityLabel(Text("Typ posiłku"))
        }
        .monoCard(padding: 16)
    }
}

/// `portion_card` (grams slider) + the "Kalorie" stepper card.
struct ManualPortionCard: View {
    @Binding var quantityGrams: Double
    @Binding var caloriesKcal: Double

    var body: some View {
        VStack(spacing: 10) {
            AddFlowPortionCard(grams: $quantityGrams, range: 1...2000, step: 5)
            HStack(spacing: 8) {
                MonoLabel(text: L("Kalorie"))
                Spacer(minLength: 0)
                MonoStepper(value: $caloriesKcal, range: 0...3000, step: 5, unit: "kcal")
            }
            .monoCard(padding: 16)
        }
    }
}

/// "Makro (opcjonalnie)" card: one stepper row per macro.
struct ManualMacrosCard: View {
    @Binding var proteinGrams: Double
    @Binding var carbsGrams: Double
    @Binding var fatGrams: Double
    @Binding var fiberGrams: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoLabel(text: L("Makro (opcjonalnie)"))
                .padding(.bottom, 4)
            ManualNumericRow(
                config: .init(symbol: "fork.knife", label: "Protein", range: 0...300, step: 1, unit: "g"),
                value: $proteinGrams
            )
            ManualNumericRow(
                config: .init(symbol: "leaf.fill", label: "Węgle", range: 0...400, step: 1, unit: "g"),
                value: $carbsGrams
            )
            ManualNumericRow(
                config: .init(symbol: "drop.fill", label: "Tłuszcz", range: 0...200, step: 1, unit: "g"),
                value: $fatGrams
            )
            ManualNumericRow(
                config: .init(symbol: "leaf", label: "Fiber", range: 0...100, step: 1, unit: "g"),
                value: $fiberGrams
            )
        }
        .monoCard(padding: 16)
    }
}

/// `rows([row('star', 'Dodaj do moich przepisów', sub, toggle)])`.
struct ManualFavoriteToggleCard: View {
    @Binding var isOn: Bool

    var body: some View {
        MonoRow(
            icon: isOn ? "star.fill" : "star",
            title: L("Add to my recipes"),
            sub: L("Szybki ponowny dodatek z karuzeli na Dziś")
        ) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(MonoToggleStyle())
        }
        .monoRowsCard()
    }
}

/// Shown instead of the favorite toggle when favorites are a Premium feature.
struct ManualFavoritePromoCard: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "lock", style: .dark, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Moje przepisy — Premium")
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Zapisuj stałe posiłki i dodawaj jednym tapnięciem.")
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            .monoCard(padding: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
