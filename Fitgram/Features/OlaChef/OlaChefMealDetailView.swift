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

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        header
                        modePicker
                        ingredientsCard
                        recipeCard
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomCTA
            }
            .navigationTitle(Text(L("Kuchnia Oli")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                            .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
                    }
                    .buttonStyle(.pressable)
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
    private var header: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(suggestion.name())
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                HStack(spacing: Tokens.Space.sm) {
                    macroPill(
                        String.localizedStringWithFormat(L("%lld kcal"), Int(currentCalories.rounded())),
                        Tokens.Palette.warning)
                    macroPill(
                        String.localizedStringWithFormat(L("%lld g"), Int(currentGrams.rounded())),
                        Tokens.Palette.primary)
                    macroPill(
                        String.localizedStringWithFormat(L("%lld min"), suggestion.dish.prepMinutes),
                        Tokens.Palette.accent)
                }
                HStack(spacing: Tokens.Space.sm) {
                    nutritionBlock(L("Protein"), currentProtein)
                    nutritionBlock(L("Carbs"), currentCarbs)
                    nutritionBlock(L("Fat"), currentFat)
                }
            }
        }
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

    private var ingredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(portionMode == .overall ? L("Porcja") : L("Składniki"))
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(
                            portionMode == .overall
                                ? L("Dopasuj wagę przed dodaniem") : L("Edytuj gramaturę produktu przed zapisem")
                        )
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(currentGrams.rounded())))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Tokens.Palette.primarySoft))
                }

                if portionMode == .overall {
                    Slider(value: $grams, in: 100...900, step: 5)
                        .tint(Tokens.Palette.primary)
                    HStack {
                        Text(String.localizedStringWithFormat(L("%lld g"), 100))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                        Spacer()
                        Text(String.localizedStringWithFormat(L("%lld g"), 900))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
                } else {
                    ForEach($ingredientDrafts) { $draft in
                        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                            HStack {
                                TextField(L("Produkt"), text: $draft.name)
                                    .font(Tokens.Font.bodyEmphasized)
                                    .textFieldStyle(.roundedBorder)
                                    .submitLabel(.done)
                                if ingredientDrafts.count > 1 {
                                    Button {
                                        ingredientDrafts.removeAll { $0.id == draft.id }
                                        Haptics.selection()
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundStyle(Tokens.Palette.error)
                                    }
                                    .buttonStyle(.pressable)
                                }
                            }
                            HStack {
                                Text(String.localizedStringWithFormat(L("%lld g"), Int(draft.grams.rounded())))
                                    .font(Tokens.Font.title3)
                                    .foregroundStyle(Tokens.Palette.primary)
                                Spacer()
                                Text(
                                    String.localizedStringWithFormat(L("%lld kcal"), Int(draft.caloriesKcal.rounded()))
                                )
                                .font(Tokens.Font.footnote.weight(.bold))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Slider(value: $draft.grams, in: 10...800, step: 5)
                                .tint(Tokens.Palette.primary)
                        }
                        if draft.id != ingredientDrafts.last?.id {
                            Divider().background(Tokens.Palette.separator)
                        }
                    }

                    Button {
                        ingredientDrafts.append(OlaChefIngredientDraft.empty())
                        Haptics.selection()
                    } label: {
                        Label(L("Dodaj składnik"), systemImage: "plus.circle.fill")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private var recipeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text(L("Przepis"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(Array(suggestion.dish.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text("\(index + 1)")
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(Tokens.Palette.primary))
                        Text(step)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                }
                Toggle(L("Dodaj do moich przepisów"), isOn: $saveAsFavorite)
                    .font(Tokens.Font.bodyEmphasized)
            }
        }
    }

    private var bottomCTA: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(title: isSaving ? "Dodaję..." : "Dodaj do dziennika", systemImage: "checkmark") {
                save()
            }
            .disabled(isSaving)
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.md)
        .padding(.bottom, Tokens.Space.lg)
        .background(.ultraThinMaterial)
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
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Capsule().fill(tint.opacity(0.13)))
    }

    private func nutritionBlock(_ title: String, _ value: Double) -> some View {
        VStack(spacing: 3) {
            Text(String.localizedStringWithFormat(L("%lld g"), Int(value.rounded())))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
            Text(title)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.7))
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
