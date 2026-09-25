import SwiftUI

/// Grams slider with quick presets for the overall portion.
struct FoodDetailPortionCard: View {
    @Binding var grams: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Porcja"))
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Dopasuj wagę przed dodaniem"))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(grams.rounded())))
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Slider(value: $grams, in: 10...600, step: 5)
                .tint(Tokens.Palette.primary)
                .padding(.vertical, Tokens.Space.xs)

            HStack(spacing: Tokens.Space.sm) {
                ForEach([100, 150, 250, 400], id: \.self) { preset in
                    portionPresetButton(preset)
                }
            }

            HStack {
                Text(String.localizedStringWithFormat(L("%lld g"), 10))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), 600))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }

    private func portionPresetButton(_ preset: Int) -> some View {
        Button {
            withAnimation(Tokens.Motion.quick) {
                grams = Double(preset)
            }
            Haptics.selection()
        } label: {
            Text(String.localizedStringWithFormat(L("%lld g"), preset))
                .font(Tokens.Font.caption.weight(.bold))
                .foregroundStyle(Int(grams.rounded()) == preset ? .white : Tokens.Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Int(grams.rounded()) == preset ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                )
        }
        .buttonStyle(.pressable)
    }
}

/// Protein / carbs / fat for the chosen portion.
struct FoodDetailMacroCard: View {
    let protein: Double
    let carbs: Double
    let fat: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text(L("Makro"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text(L("na wybraną porcję"))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            HStack(spacing: Tokens.Space.sm) {
                FoodDetailMacroPill(label: L("Protein"), grams: protein, color: Tokens.Palette.primary)
                FoodDetailMacroPill(label: L("Węgle"), grams: carbs, color: Tokens.Palette.warning)
                FoodDetailMacroPill(label: L("Tłuszcz"), grams: fat, color: Tokens.Palette.accent)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }
}

struct FoodDetailMacroPill: View {
    let label: String
    let grams: Double
    let color: Color

    var body: some View {
        VStack(spacing: 5) {
            Text(String(format: "%.1f g", grams))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.11))
        )
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
