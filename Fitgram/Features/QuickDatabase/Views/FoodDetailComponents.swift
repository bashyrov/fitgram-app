import SwiftUI

/// `portion_card(g, pct)`: "PORCJA" label + italic grams, slider with range labels,
/// quick preset chips and the "Dopasuj wagę przed dodaniem" hint.
struct FoodDetailPortionCard: View {
    @Binding var grams: Double
    var range: ClosedRange<Double> = 10...1500

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MonoLabel(text: L("Porcja"))
                Spacer(minLength: 0)
                Text(String.localizedStringWithFormat(L("%lld g"), Int(grams.rounded())))
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                    .lineLimit(1)
            }
            VStack(spacing: 6) {
                Slider(value: $grams, in: range, step: 5)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.lowerBound)))
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.upperBound)))
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            HStack(spacing: 6) {
                ForEach([100, 150, 250, 400], id: \.self) { preset in
                    portionPresetButton(preset)
                }
            }
            Text(L("Dopasuj wagę przed dodaniem"))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }

    private func portionPresetButton(_ preset: Int) -> some View {
        let isSelected = Int(grams.rounded()) == preset
        return Button {
            withAnimation(Tokens.Motion.quick) {
                grams = Double(preset)
            }
            Haptics.selection()
        } label: {
            Text(String.localizedStringWithFormat(L("%lld g"), preset))
                .font(Tokens.Font.manrope(13, weight: isSelected ? 800 : 700))
                .foregroundStyle(isSelected ? Tokens.Mono.onHero : Tokens.Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(Capsule().fill(isSelected ? Tokens.Mono.hero : Color.clear))
                .overlay(Capsule().stroke(isSelected ? Color.clear : Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Protein / carbs / fat for the chosen portion (light macro chips).
struct FoodDetailMacroCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Makro"))
                Spacer(minLength: 8)
                Text(L("na wybraną porcję"))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            MonoMacroRow(protein: protein, carbs: carbs, fat: fat)
        }
        .monoCard(padding: 16)
    }
}

struct FoodDetailMacroPill: View {
    let label: String
    let grams: Double
    let color: Color

    var body: some View {
        MonoMacroChip(label: label, grams: grams, dot: color)
    }
}

struct FoodDetailFavoriteContext {
    let favoritesService: any FavoritesServing
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let userRemoteID: String
}

struct QuickFoodIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantityGrams: Double
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double
    var fiberGramsPer100g: Double?

    init(
        name: String,
        quantityGrams: Double,
        caloriesKcalPer100g: Double = 0,
        proteinGramsPer100g: Double = 0,
        carbsGramsPer100g: Double = 0,
        fatGramsPer100g: Double = 0,
        fiberGramsPer100g: Double? = nil
    ) {
        self.name = name
        self.quantityGrams = quantityGrams
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
        self.fiberGramsPer100g = fiberGramsPer100g
    }

    var factor: Double { quantityGrams / 100 }
    var caloriesKcal: Double { caloriesKcalPer100g * factor }
    var proteinGrams: Double { proteinGramsPer100g * factor }
    var carbsGrams: Double { carbsGramsPer100g * factor }
    var fatGrams: Double { fatGramsPer100g * factor }
    var fiberGrams: Double? { fiberGramsPer100g.map { $0 * factor } }
}

extension QuickFoodIngredientDraft {
    /// One row for a catalog food at the given portion.
    init(food: Food, grams: Double) {
        self.init(
            name: food.localizedName,
            quantityGrams: grams,
            caloriesKcalPer100g: food.caloriesKcalPer100g,
            proteinGramsPer100g: food.proteinGramsPer100g,
            carbsGramsPer100g: food.carbsGramsPer100g,
            fatGramsPer100g: food.fatGramsPer100g,
            fiberGramsPer100g: food.fiberGramsPer100g
        )
    }

    /// One row per item of a past meal, scaled by its portion multiplier.
    init(item: MealEntrySnapshot.Item, portionMultiplier: Double) {
        let per100g: (Double) -> Double = { value in
            item.quantityGrams > 0 ? value / item.quantityGrams * 100 : 0
        }
        self.init(
            name: item.name,
            quantityGrams: item.quantityGrams * portionMultiplier,
            caloriesKcalPer100g: per100g(item.caloriesKcal),
            proteinGramsPer100g: per100g(item.proteinGrams),
            carbsGramsPer100g: per100g(item.carbsGrams),
            fatGramsPer100g: per100g(item.fatGrams),
            fiberGramsPer100g: item.quantityGrams > 0 ? item.fiberGrams.map(per100g) : nil
        )
    }
}

extension MealEntrySnapshot {
    /// Total eaten grams, never below 1 so per-100 g math stays finite.
    var eatenGrams: Double {
        max(items.reduce(0) { $0 + $1.quantityGrams } * portionMultiplier, 1)
    }
}

extension Food {
    /// Unsaved catalog-style food describing a past meal, so it can be
    /// re-logged through the Quick Database detail sheet.
    static func repeating(_ snapshot: MealEntrySnapshot) -> Food {
        let items = snapshot.items
        let totalGrams = snapshot.eatenGrams
        let title =
            snapshot.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? snapshot.notes ?? L("Ostatni posiłek")
            : items.prefix(2).map(\.name).joined(separator: " + ")
        let per100g: (Double) -> Double = { total in total * snapshot.portionMultiplier / totalGrams * 100 }
        return Food(
            name: title.isEmpty ? L("Ostatni posiłek") : title,
            category: .homemade,
            caloriesKcalPer100g: per100g(items.reduce(0) { $0 + $1.caloriesKcal }),
            proteinGramsPer100g: per100g(items.reduce(0) { $0 + $1.proteinGrams }),
            carbsGramsPer100g: per100g(items.reduce(0) { $0 + $1.carbsGrams }),
            fatGramsPer100g: per100g(items.reduce(0) { $0 + $1.fatGrams }),
            defaultPortionGrams: totalGrams,
            verified: false
        )
    }
}
