import SwiftUI

/// Confirmation sheet shown after the user taps a food in the Quick
/// Database list. Portion slider, macro preview, save → MealEntry.
struct FoodDetailSheet: View {
    let food: Food
    let onSave: (FoodItem) -> Void
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?

    @State private var grams: Double

    init(
        food: Food,
        onSave: @escaping (FoodItem) -> Void,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil
    ) {
        self.food = food
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self._grams = State(initialValue: food.defaultPortionGrams ?? 100)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryCard
                        favoriteButton
                        portionCard
                        macroCard
                        PrimaryButton(title: "Dodaj do dziennika", systemImage: "checkmark") {
                            commit()
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(food.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if let favoritesService,
            let entitlementsStore,
            let paywallCoordinator,
            let userRemoteID {
            let factor = grams / 100
            FavoriteToggleButton(
                payload: FavoriteToggleButton.Payload(
                    name: food.name,
                    quantityGrams: grams,
                    caloriesKcal: food.caloriesKcalPer100g * factor,
                    proteinGrams: food.proteinGramsPer100g * factor,
                    carbsGrams: food.carbsGramsPer100g * factor,
                    fatGrams: food.fatGramsPer100g * factor,
                    fiberGrams: food.fiberGramsPer100g.map { $0 * factor },
                    source: .quickDatabase,
                    catalogFoodID: food.id
                ),
                userRemoteID: userRemoteID,
                favoritesService: favoritesService,
                entitlementsStore: entitlementsStore,
                paywallCoordinator: paywallCoordinator
            )
        }
    }

    // MARK: - Sections

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                if let brand = food.brand ?? food.restaurantName {
                    Text(brand)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Text("\(Int(currentCalories)) kcal")
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
                Text("\(Int(grams)) g")
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
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Slider(value: $grams, in: 10...600, step: 5)
                    .tint(Tokens.Palette.primary)
                HStack {
                    Text("10 g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("600 g")
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
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Math

    private var scale: Double { grams / 100.0 }
    private var currentCalories: Double { food.caloriesKcalPer100g * scale }
    private var currentProtein: Double { food.proteinGramsPer100g * scale }
    private var currentCarbs: Double { food.carbsGramsPer100g * scale }
    private var currentFat: Double { food.fatGramsPer100g * scale }

    private func commit() {
        let item = FoodItem.from(food: food, quantityGrams: grams, confidence: 1.0)
        onSave(item)
        onDismiss()
    }
}
