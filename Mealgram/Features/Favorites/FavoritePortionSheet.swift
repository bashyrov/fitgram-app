import SwiftUI

/// Portion picker raised when the user taps a saved favourite ("Moje
/// przepisy") on Today or in the list view. Pre-fills with the
/// favourite's stored defaultQuantityGrams so the user starts from
/// "what they normally eat" and only adjusts when the portion differs.
///
/// All macro values scale linearly with the grams slider (the favourite
/// already stores absolute kcal/macro at its default portion, so the
/// factor is `grams / defaultQuantityGrams`).
struct FavoritePortionSheet: View {
    let favorite: FavoriteMeal
    let onSave: (Double) -> Void
    let onDismiss: () -> Void

    @State private var grams: Double

    init(favorite: FavoriteMeal, onSave: @escaping (Double) -> Void, onDismiss: @escaping () -> Void) {
        self.favorite = favorite
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._grams = State(initialValue: favorite.defaultQuantityGrams)
    }

    private var factor: Double {
        guard favorite.defaultQuantityGrams > 0 else { return 1 }
        return grams / favorite.defaultQuantityGrams
    }

    private var currentCalories: Double { favorite.caloriesKcal * factor }
    private var currentProtein: Double { favorite.proteinGrams * factor }
    private var currentCarbs: Double { favorite.carbsGrams * factor }
    private var currentFat: Double { favorite.fatGrams * factor }

    /// Slider bounds — anchor around the favourite's default so the
    /// thumb starts roughly in the middle. Clamped to a sane edible
    /// range (10 g – 1500 g).
    private var range: ClosedRange<Double> {
        let lower = max(10, favorite.defaultQuantityGrams * 0.2)
        let upper = min(1500, max(favorite.defaultQuantityGrams * 3, 600))
        return lower...upper
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryCard
                        portionCard
                        macroCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(favorite.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Anuluj", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Dodaj") {
                        Haptics.success()
                        onSave(grams)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("Z Twoich przepisów")
                        .font(.system(size: 11, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.8)
                        .foregroundStyle(Tokens.Palette.warning)
                }
                Text("\(Int(currentCalories.rounded())) kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                Text("\(Int(grams)) g porcja")
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private var portionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text("\(Int(grams)) g")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.primary)
                        .contentTransition(.numericText())
                }
                Slider(value: $grams, in: range, step: 5) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(Tokens.Palette.primary)
                HStack {
                    Text("\(Int(range.lowerBound)) g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("Domyślnie \(Int(favorite.defaultQuantityGrams)) g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("\(Int(range.upperBound)) g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
    }

    private var macroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Makro")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Białko", grams: currentProtein, color: Tokens.Palette.primary)
                    macroPill(label: "Węgle", grams: currentCarbs, color: Tokens.Palette.warning)
                    macroPill(label: "Tłuszcz", grams: currentFat, color: Tokens.Palette.accent)
                }
            }
        }
    }

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.1f g", grams))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
