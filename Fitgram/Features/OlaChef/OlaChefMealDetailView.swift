import OSLog
import SwiftUI

struct OlaChefMealDetailView: View {
    let suggestion: OlaChefSuggestion
    let mealType: MealType
    let mealSaver: any MealSaving
    let userRemoteID: String
    let favoritesService: (any FavoritesServing)?
    let onClose: () -> Void
    let onSaved: () -> Void

    @State private var saveAsFavorite = true
    @State private var isSaving = false
    @State private var error: String?
    @State private var portionMode: PortionAdjustmentMode = .detailed
    @State private var grams: Double = 0
    @State private var ingredientDrafts: [OlaChefIngredientDraft] = []

    /// Mockup `OlaChefMeal`: h1 (name + meal · min · g) · dark kcal hero with macro chips · portion
    /// mode · portion card / ingredients · "Przepis" steps · favourite toggle row · bottom CTA.
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: suggestion.name(), sub: headerSubtitle)
                    header
                        .padding(.top, 14)
                    modePicker
                        .padding(.top, 10)
                    ingredientsCard
                        .padding(.top, 10)
                    recipeCard
                    favoriteRow
                        .padding(.top, 10)
                    if let error {
                        Text(error)
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.danger)
                            .padding(.horizontal, 6)
                            .padding(.top, 10)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
            .monoNavigationTitle(L("Kuchnia Oli"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onClose)
                        .accessibilityLabel(L("Zamknij"))
                }
            }
        }
        .onAppear {
            if grams <= 0 {
                grams = suggestion.servingGrams
            }
            if ingredientDrafts.isEmpty {
                ingredientDrafts = suggestion.ingredients.map(OlaChefIngredientDraft.init)
            }
        }
    }
}

// MARK: - Sections
extension OlaChefMealDetailView {
    /// "Obiad · 25 min · 420 g".
    private var headerSubtitle: String {
        [
            mealTypeTitle,
            String.localizedStringWithFormat(L("%lld min"), suggestion.dish.prepMinutes),
            String.localizedStringWithFormat(L("%lld g"), Int(currentGrams.rounded())),
        ].joined(separator: " · ")
    }

    private var mealTypeTitle: String {
        switch mealType {
        case .breakfast: return L("Śniadanie")
        case .lunch: return L("Obiad")
        case .dinner: return L("Kolacja")
        case .snack: return L("Przekąska")
        }
    }

    /// `hero(num(52) kcal + macro_pills(dark))`.
    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(Int(currentCalories.rounded()))")
                    .font(Tokens.Font.monoNumber(52))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text(verbatim: "kcal")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            MonoMacroRow(protein: currentProtein, carbs: currentCarbs, fat: currentFat, dark: true)
        }
        .monoHero(padding: 18)
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Zapiszemy jedną pozycję. AI możesz poprawić nazwą, wagą i makro."),
            detailLabel: L("Zapiszemy składniki osobno. Każdy produkt możesz zważyć przed dodaniem."),
            detailCount: max(1, ingredientDrafts.count)
        )
        .onChange(of: portionMode) { _, newValue in
            if newValue == .detailed, ingredientDrafts.isEmpty {
                ingredientDrafts = suggestion.ingredients.map(OlaChefIngredientDraft.init)
            }
            if newValue == .overall, currentGrams > 0 {
                grams = currentGrams
            }
        }
    }

    /// General mode → `portion_card`; detailed mode → `ingr_list` with weighed ingredients.
    @ViewBuilder
    private var ingredientsCard: some View {
        if portionMode == .overall {
            AddFlowPortionCard(grams: $grams, range: 100...900, step: 5)
        } else {
            AddFlowIngredientsSection(
                title: L("Składniki"),
                count: ingredientDrafts.count,
                sub: L("Edytuj gramaturę produktu przed zapisem")
            ) {
                ForEach($ingredientDrafts) { $draft in
                    AddFlowIngredientRow(
                        showsDivider: draft.id != ingredientDrafts.first?.id,
                        kcal: draft.caloriesKcal,
                        grams: $draft.grams,
                        range: 10...800,
                        step: 5,
                        onRemove: removeAction(for: draft.id)
                    ) {
                        TextField(L("Produkt"), text: $draft.name)
                            .submitLabel(.done)
                    }
                }
            } footer: {
                MonoButton(title: L("Dodaj składnik"), kind: .outline, icon: "plus", height: 44) {
                    ingredientDrafts.append(OlaChefIngredientDraft.empty())
                    Haptics.selection()
                }
            }
        }
    }

    private func removeAction(for id: UUID) -> (() -> Void)? {
        guard ingredientDrafts.count > 1 else { return nil }
        return {
            ingredientDrafts.removeAll { $0.id == id }
        }
    }

    /// `sec('Przepis')` + card of numbered steps (28 pt track circles, 14/600 text).
    private var recipeCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Przepis"))
                .padding(.horizontal, 6)
                .padding(.top, 22 - Tokens.Space.lg)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(suggestion.dish.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text(verbatim: "\(index + 1)")
                            .font(Tokens.Font.monoNumber(13))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Tokens.Mono.track))
                        Text(step)
                            .font(Tokens.Font.manrope(14, weight: 600))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .monoCard(padding: 16)
        }
    }

    /// `rows([row('book', 'Dodaj do moich przepisów', toggle)])`.
    private var favoriteRow: some View {
        MonoRow(icon: "book", title: L("Dodaj do moich przepisów")) {
            Toggle("", isOn: $saveAsFavorite)
                .labelsHidden()
                .toggleStyle(MonoToggleStyle())
        }
        .monoRowsCard()
    }

    private var bottomCTA: some View {
        MonoBottomBar {
            MonoButton(title: isSaving ? L("Dodaję...") : L("Dodaj do dziennika"), kind: .dark, icon: "checkmark") {
                save()
            }
            .disabled(isSaving)
        }
    }
}

// MARK: - Saving
extension OlaChefMealDetailView {
    private func save() {
        guard !isSaving else { return }
        isSaving = true
        let language = LocalizationStore.currentLanguageCode()
        let meal = MealEntry(
            mealType: mealType,
            source: .manual,
            notes: suggestion.name(languageCode: language),
            tags: ["ola-chef", suggestion.dish.cuisine.lowercased()],
            items: itemsToSave(languageCode: language)
        )
        do {
            try mealSaver.save(meal: meal)
            if saveAsFavorite, let favoritesService {
                try? favoritesService.add(
                    FavoriteMeal(
                        userRemoteID: userRemoteID,
                        name: suggestion.name(languageCode: language),
                        defaultQuantityGrams: currentGrams,
                        caloriesKcal: currentCalories,
                        proteinGrams: currentProtein,
                        carbsGrams: currentCarbs,
                        fatGrams: currentFat,
                        source: .manual
                    )
                )
            }
            Haptics.success()
            NotificationCenter.default.post(name: Notification.Name("FitgramMealSaved"), object: nil)
            onSaved()
        } catch {
            Logger.persistence.error("Kuchnia Oli save failed: \(String(describing: error))")
            self.error = L("Couldn't save. Try again.")
            isSaving = false
        }
    }

    private func macroPill(_ text: String, _ tint: Color) -> some View {
        Text(text)
            .font(Tokens.Font.manrope(12, weight: 800))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay(Capsule().stroke(Tokens.Mono.heroLine, lineWidth: 1))
    }

    private func nutritionBlock(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text(String.localizedStringWithFormat(L("%lld g"), Int(value.rounded())))
                .font(Tokens.Font.monoNumber(22))
                .foregroundStyle(Tokens.Mono.onHero)
            Text(title)
                .font(Tokens.Font.manrope(11, weight: 800))
                .textCase(.uppercase)
                .tracking(1)
                .foregroundStyle(Tokens.Mono.heroMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                .stroke(Tokens.Mono.heroLine, lineWidth: 1)
        )
    }
}

// MARK: - Portion math
extension OlaChefMealDetailView {
    private var overallFactor: Double {
        guard suggestion.servingGrams > 0 else { return 1 }
        return grams / suggestion.servingGrams
    }

    private var currentGrams: Double {
        switch portionMode {
        case .overall:
            return grams
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.grams }
        }
    }

    private var currentCalories: Double {
        switch portionMode {
        case .overall:
            return suggestion.caloriesKcal * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.caloriesKcal }
        }
    }

    private var currentProtein: Double {
        switch portionMode {
        case .overall:
            return suggestion.proteinGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.proteinGrams }
        }
    }

    private var currentCarbs: Double {
        switch portionMode {
        case .overall:
            return suggestion.carbsGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.carbsGrams }
        }
    }

    private var currentFat: Double {
        switch portionMode {
        case .overall:
            return suggestion.fatGrams * overallFactor
        case .detailed:
            return ingredientDrafts.reduce(0) { $0 + $1.fatGrams }
        }
    }

    private func itemsToSave(languageCode: String) -> [FoodItem] {
        switch portionMode {
        case .overall:
            return [
                FoodItem(
                    name: suggestion.name(languageCode: languageCode),
                    quantityGrams: grams,
                    caloriesKcal: currentCalories,
                    proteinGrams: currentProtein,
                    carbsGrams: currentCarbs,
                    fatGrams: currentFat,
                    confidence: 1.0
                )
            ]
        case .detailed:
            return ingredientDrafts.map { draft in
                FoodItem(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? L("Produkt")
                        : draft.name,
                    quantityGrams: draft.grams,
                    caloriesKcal: draft.caloriesKcal,
                    proteinGrams: draft.proteinGrams,
                    carbsGrams: draft.carbsGrams,
                    fatGrams: draft.fatGrams,
                    confidence: 1.0
                )
            }
        }
    }
}

private struct OlaChefIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var grams: Double
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double

    init(ingredient: OlaChefIngredient) {
        self.name = ingredient.name()
        self.grams = ingredient.grams
        let factor = max(ingredient.grams, 1) / 100
        self.caloriesKcalPer100g = ingredient.caloriesKcal / factor
        self.proteinGramsPer100g = ingredient.proteinGrams / factor
        self.carbsGramsPer100g = ingredient.carbsGrams / factor
        self.fatGramsPer100g = ingredient.fatGrams / factor
    }

    static func empty() -> OlaChefIngredientDraft {
        OlaChefIngredientDraft(
            name: "",
            grams: 100,
            caloriesKcalPer100g: 0,
            proteinGramsPer100g: 0,
            carbsGramsPer100g: 0,
            fatGramsPer100g: 0
        )
    }

    private init(
        name: String,
        grams: Double,
        caloriesKcalPer100g: Double,
        proteinGramsPer100g: Double,
        carbsGramsPer100g: Double,
        fatGramsPer100g: Double
    ) {
        self.name = name
        self.grams = grams
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
    }

    private var factor: Double { grams / 100 }
    var caloriesKcal: Double { caloriesKcalPer100g * factor }
    var proteinGrams: Double { proteinGramsPer100g * factor }
    var carbsGrams: Double { carbsGramsPer100g * factor }
    var fatGrams: Double { fatGramsPer100g * factor }
}
