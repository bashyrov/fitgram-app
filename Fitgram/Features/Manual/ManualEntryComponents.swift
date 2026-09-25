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

/// Icon + label + current value with a stepper, for one nutrition number.
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
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle().fill(config.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: config.symbol)
                    .foregroundStyle(config.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(config.label)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(value))")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(config.unit)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            Stepper("", value: $value, in: config.range, step: config.step)
                .labelsHidden()
        }
    }
}

struct ManualMealTypeCard: View {
    @Binding var mealType: MealType

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Posiłek")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Picker("Typ posiłku", selection: $mealType) {
                    Text("Breakfast").tag(MealType.breakfast)
                    Text("Lunch").tag(MealType.lunch)
                    Text("Dinner").tag(MealType.dinner)
                    Text("Snack").tag(MealType.snack)
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

struct ManualPortionCard: View {
    @Binding var quantityGrams: Double
    @Binding var caloriesKcal: Double

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                ManualNumericRow(
                    config: .init(
                        symbol: "scalemass",
                        label: "Porcja",
                        range: 1...2000,
                        step: 5,
                        unit: "g"
                    ),
                    value: $quantityGrams
                )
                ManualNumericRow(
                    config: .init(
                        symbol: "flame.fill",
                        label: "Kalorie",
                        range: 0...3000,
                        step: 5,
                        unit: "kcal",
                        tint: Tokens.Palette.warning
                    ),
                    value: $caloriesKcal
                )
            }
        }
    }
}

struct ManualMacrosCard: View {
    @Binding var proteinGrams: Double
    @Binding var carbsGrams: Double
    @Binding var fatGrams: Double
    @Binding var fiberGrams: Double

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Makro (opcjonalnie)")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
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
        }
    }
}

struct ManualFavoriteToggleCard: View {
    @Binding var isOn: Bool

    var body: some View {
        Card {
            Toggle(isOn: $isOn) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: isOn ? "star.fill" : "star")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add to my recipes")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Szybki ponowny dodatek z karuzeli na Dziś")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
            }
            .tint(Tokens.Palette.primary)
        }
    }
}

/// Shown instead of the favorite toggle when favorites are a Premium feature.
struct ManualFavoritePromoCard: View {
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Card(background: Tokens.Palette.primarySoft) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moje przepisy — Premium")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Zapisuj stałe posiłki i dodawaj jednym tapnięciem.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
