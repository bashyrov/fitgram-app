import SwiftUI

/// Confirmation sheet shown after the user taps a food in the Quick
/// Database list. Portion slider, macro preview, save → MealEntry.
struct FoodDetailSheet: View {
    let food: Food
    let onSave: ([FoodItem]) -> Void
    let onDismiss: () -> Void
    private let heroSubtitle: String?
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    @State private var grams: Double
    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var detailDrafts: [QuickFoodIngredientDraft]
    @State private var productLookupsInFlight: Set<UUID> = []
    @FocusState private var isTextInputFocused: Bool

    init(
        food: Food,
        onSave: @escaping ([FoodItem]) -> Void,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil,
        mealAnalyzer: MealTextAnalysisService? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self.food = food
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self.mealAnalyzer = mealAnalyzer
        self.usageMeter = usageMeter
        self.heroSubtitle = nil
        let initialGrams = food.defaultPortionGrams ?? 100
        self._grams = State(initialValue: initialGrams)
        self._detailDrafts = State(initialValue: [QuickFoodIngredientDraft(food: food, grams: initialGrams)])
    }

    init(
        repeating snapshot: MealEntrySnapshot,
        onSave: @escaping ([FoodItem]) -> Void,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil,
        mealAnalyzer: MealTextAnalysisService? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        let items = snapshot.items
        let totalGrams = snapshot.eatenGrams
        let syntheticFood = Food.repeating(snapshot)
        self.food = syntheticFood
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self.mealAnalyzer = mealAnalyzer
        self.usageMeter = usageMeter
        self.heroSubtitle = L("Powtórz ostatnie zapisane danie")
        self._grams = State(initialValue: totalGrams)
        self._portionMode = State(initialValue: items.count > 1 ? .detailed : .overall)
        self._detailDrafts = State(
            initialValue: items.map {
                QuickFoodIngredientDraft(item: $0, portionMultiplier: snapshot.portionMultiplier)
            }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    summaryHero
                    modePicker
                    if portionMode == .overall {
                        FoodDetailPortionCard(grams: $grams)
                        MonoHint(text: L("Jedna pozycja z bazy produktów."))
                    } else {
                        detailedIngredientsCard
                    }
                    favoriteButton
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(food.localizedName)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                        .accessibilityLabel(Text(L("Close")))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Gotowe")) {
                        commit()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("Gotowe")) {
                        isTextInputFocused = false
                    }
                    .font(Tokens.Font.bodyEmphasized)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Dodaj do dziennika"), kind: .dark, icon: "checkmark") {
                        commit()
                    }
                }
            }
        }
    }
}

// MARK: - Chrome
extension FoodDetailSheet {
    @ViewBuilder
    private var favoriteButton: some View {
        if let context = favoriteContext {
            let favoriteItems = itemsToSave()
            FavoriteToggleButton(
                payload: FavoriteToggleButton.Payload(
                    name: food.localizedName,
                    quantityGrams: favoriteItems.reduce(0) { $0 + $1.quantityGrams },
                    caloriesKcal: favoriteItems.reduce(0) { $0 + $1.caloriesKcal },
                    proteinGrams: favoriteItems.reduce(0) { $0 + $1.proteinGrams },
                    carbsGrams: favoriteItems.reduce(0) { $0 + $1.carbsGrams },
                    fatGrams: favoriteItems.reduce(0) { $0 + $1.fatGrams },
                    fiberGrams: favoriteFiberGrams(for: favoriteItems),
                    source: .quickDatabase,
                    catalogFoodID: food.id
                ),
                userRemoteID: context.userRemoteID,
                favoritesService: context.favoritesService,
                entitlementsStore: context.entitlementsStore,
                paywallCoordinator: context.paywallCoordinator
            )
        }
    }

    private var favoriteContext: FoodDetailFavoriteContext? {
        guard let favoritesService, let entitlementsStore, let paywallCoordinator, let userRemoteID else {
            return nil
        }
        return FoodDetailFavoriteContext(
            favoritesService: favoritesService,
            entitlementsStore: entitlementsStore,
            paywallCoordinator: paywallCoordinator,
            userRemoteID: userRemoteID
        )
    }
}

// MARK: - Sections
extension FoodDetailSheet {
    /// `total_hero(kcal, 'Baza · 250 g · Dania główne', p, c, f, 'books')`.
    private var summaryHero: some View {
        AddFlowTotalHero(
            icon: "books.vertical",
            caption: heroCaption,
            kcal: currentCalories,
            protein: currentProtein,
            carbs: currentCarbs,
            fat: currentFat
        )
    }

    private var heroCaption: String {
        let candidates = [food.restaurantName, food.brand].compactMap { $0 }.filter { !$0.isEmpty }
        let source = candidates.first ?? food.category.localizedLabel
        let gramsText = String.localizedStringWithFormat(L("%lld g"), Int(grams.rounded()))
        return [heroSubtitle ?? L("Baza"), gramsText, source].joined(separator: " · ")
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedna pozycja z bazy produktów."),
            detailLabel: L("Rozbij produkt lub danie na składniki."),
            detailCount: max(1, detailDrafts.count)
        )
        .onChange(of: portionMode) { _, newValue in
            if newValue == .detailed {
                syncDetailFromOverall()
            } else {
                syncOverallFromDetail()
            }
        }
    }

    /// `ingr_list(..., 'Składniki', 'Rozbij produkt lub danie na składniki.')`.
    private var detailedIngredientsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddFlowIngredientsSection(
                title: L("Składniki"),
                count: detailDrafts.count,
                sub: L("Rozbij produkt lub danie na składniki.")
            ) {
                ForEach(Array(detailDrafts.enumerated()), id: \.element.id) { index, draft in
                    ingredientRow(draftBinding(draft.id), showsDivider: index > 0)
                }
            } footer: {
                MonoButton(title: L("Dodaj składnik"), kind: .outline, icon: "plus", height: 44) {
                    detailDrafts.append(QuickFoodIngredientDraft(name: "", quantityGrams: 100))
                    Haptics.selection()
                }
            }
            AIRequestHint.productNutrition
        }
        .onChange(of: detailDrafts) { _, _ in syncOverallFromDetail() }
    }

    /// Binding to one draft looked up by id, so rows survive removals.
    private func draftBinding(_ draftID: UUID) -> Binding<QuickFoodIngredientDraft> {
        Binding<QuickFoodIngredientDraft>(
            get: {
                detailDrafts.first(where: { $0.id == draftID })
                    ?? QuickFoodIngredientDraft(name: "", quantityGrams: 100)
            },
            set: { newValue in
                guard let index = detailDrafts.firstIndex(where: { $0.id == draftID }) else { return }
                detailDrafts[index] = newValue
            }
        )
    }

    private func ingredientRow(_ draft: Binding<QuickFoodIngredientDraft>, showsDivider: Bool) -> some View {
        let draftID = draft.wrappedValue.id
        var removeAction: (() -> Void)?
        if detailDrafts.count > 1 {
            removeAction = { detailDrafts.removeAll { $0.id == draftID } }
        }
        return AddFlowIngredientRow(
            showsDivider: showsDivider,
            kcal: draft.wrappedValue.caloriesKcal,
            grams: draft.quantityGrams,
            range: 10...1200,
            step: 5,
            onRemove: removeAction
        ) {
            TextField(L("Produkt"), text: draft.name)
                .focused($isTextInputFocused)
                .submitLabel(.done)
                .onSubmit { isTextInputFocused = false }
        } accessory: {
            productAIButton(for: draft)
        }
    }

    private func productAIButton(for draft: Binding<QuickFoodIngredientDraft>) -> some View {
        AIProductLookupButton(
            isLoading: productLookupsInFlight.contains(draft.wrappedValue.id),
            remaining: productNutritionRemaining,
            isDisabled: productLookupsInFlight.contains(draft.wrappedValue.id)
                || mealAnalyzer == nil
                || draft.wrappedValue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            accessibilityLabel: L("Uzupełnij produkt AI")
        ) {
            isTextInputFocused = false
            Task { await refreshProductNutrition(draft.wrappedValue.id) }
        }
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.productNutritionLookupsPerDay)
    }
}

// MARK: - Math
extension FoodDetailSheet {
    private var scale: Double { grams / 100.0 }
    private var currentCalories: Double {
        portionMode == .overall ? food.caloriesKcalPer100g * scale : detailDrafts.reduce(0) { $0 + $1.caloriesKcal }
    }
    private var currentProtein: Double {
        portionMode == .overall ? food.proteinGramsPer100g * scale : detailDrafts.reduce(0) { $0 + $1.proteinGrams }
    }
    private var currentCarbs: Double {
        portionMode == .overall ? food.carbsGramsPer100g * scale : detailDrafts.reduce(0) { $0 + $1.carbsGrams }
    }
    private var currentFat: Double {
        portionMode == .overall ? food.fatGramsPer100g * scale : detailDrafts.reduce(0) { $0 + $1.fatGrams }
    }

    private var detailTotalGrams: Double {
        detailDrafts.reduce(0) { $0 + $1.quantityGrams }
    }

    private func syncDetailFromOverall() {
        guard detailDrafts.count == 1 else { return }
        detailDrafts[0].quantityGrams = grams
    }

    private func syncOverallFromDetail() {
        guard portionMode == .detailed else { return }
        grams = detailTotalGrams
    }

    private func refreshProductNutrition(_ draftID: UUID) async {
        guard let mealAnalyzer,
            let draft = detailDrafts.first(where: { $0.id == draftID })
        else { return }
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, draft.quantityGrams > 0 else { return }
        let cap = entitlementsStore?.current.productNutritionLookupsPerDay
        if usageMeter?.canUse(.productNutritionLookup, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.productNutritionQuota)
            return
        }
        productLookupsInFlight.insert(draftID)
        defer { productLookupsInFlight.remove(draftID) }
        let mealType = QuickDatabaseRootView.suggestedMealType()
        let analysis = await mealAnalyzer.analyze(
            text: "\(Int(draft.quantityGrams.rounded())) g \(trimmed)",
            mealType: mealType,
            quotaKind: .productNutrition
        )
        if analysis.items.count > 1,
            let index = detailDrafts.firstIndex(where: { $0.id == draftID })
        {
            let replacement = analysis.items.map { item in
                let factor = max(item.quantityGrams, 1) / 100
                return QuickFoodIngredientDraft(
                    name: item.name,
                    quantityGrams: item.quantityGrams,
                    caloriesKcalPer100g: item.caloriesKcal / factor,
                    proteinGramsPer100g: item.proteinGrams / factor,
                    carbsGramsPer100g: item.carbsGrams / factor,
                    fatGramsPer100g: item.fatGrams / factor
                )
            }
            detailDrafts.replaceSubrange(index...index, with: replacement)
            if analysis.aiSucceeded {
                usageMeter?.record(.productNutritionLookup, cap: cap)
            }
            Haptics.success()
            return
        }
        let completed = analysis.items.first ?? analysis.overall
        if analysis.aiSucceeded {
            usageMeter?.record(.productNutritionLookup, cap: cap)
        }
        guard let index = detailDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        let factor = max(completed.quantityGrams, 1) / 100
        detailDrafts[index].name = completed.name
        detailDrafts[index].quantityGrams = completed.quantityGrams
        detailDrafts[index].caloriesKcalPer100g = completed.caloriesKcal / factor
        detailDrafts[index].proteinGramsPer100g = completed.proteinGrams / factor
        detailDrafts[index].carbsGramsPer100g = completed.carbsGrams / factor
        detailDrafts[index].fatGramsPer100g = completed.fatGrams / factor
        Haptics.success()
    }

    private func commit() {
        let items = itemsToSave()
        onSave(items)
        onDismiss()
    }

    private func favoriteFiberGrams(for items: [FoodItem]) -> Double? {
        let values = items.compactMap(\.fiberGrams)
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +)
    }

    private func itemsToSave() -> [FoodItem] {
        switch portionMode {
        case .overall:
            return [FoodItem.from(food: food, quantityGrams: grams, confidence: 1.0)]
        case .detailed:
            return detailDrafts.map { draft in
                FoodItem(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? food.localizedName
                        : draft.name,
                    quantityGrams: draft.quantityGrams,
                    caloriesKcal: draft.caloriesKcal,
                    proteinGrams: draft.proteinGrams,
                    carbsGrams: draft.carbsGrams,
                    fatGrams: draft.fatGrams,
                    fiberGrams: draft.fiberGrams
                )
            }
        }
    }
}
