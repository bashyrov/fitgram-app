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
    let onSave: ([FoodItem]) -> Void
    let onDismiss: () -> Void
    let mealAnalyzer: MealTextAnalysisService?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    let usageMeter: UsageMeter?

    @State private var grams: Double
    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var detailDrafts: [FavoriteIngredientDraft]
    @State private var productLookupsInFlight: Set<UUID> = []
    @FocusState private var isTextInputFocused: Bool

    init(
        favorite: FavoriteMeal,
        onSave: @escaping ([FoodItem]) -> Void,
        onDismiss: @escaping () -> Void,
        mealAnalyzer: MealTextAnalysisService? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self.favorite = favorite
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.mealAnalyzer = mealAnalyzer
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.usageMeter = usageMeter
        self._grams = State(initialValue: favorite.defaultQuantityGrams)
        self._detailDrafts = State(initialValue: [
            FavoriteIngredientDraft(
                name: favorite.name,
                baseQuantityGrams: favorite.defaultQuantityGrams,
                quantityGrams: favorite.defaultQuantityGrams,
                caloriesKcal: favorite.caloriesKcal,
                proteinGrams: favorite.proteinGrams,
                carbsGrams: favorite.carbsGrams,
                fatGrams: favorite.fatGrams,
                fiberGrams: favorite.fiberGrams
            )
        ])
    }

    private var factor: Double {
        guard favorite.defaultQuantityGrams > 0 else { return 1 }
        return grams / favorite.defaultQuantityGrams
    }

    private var currentCalories: Double { favorite.caloriesKcal * factor }
    private var currentProtein: Double {
        portionMode == .overall ? favorite.proteinGrams * factor : detailDrafts.reduce(0) { $0 + $1.scaledProteinGrams }
    }
    private var currentCarbs: Double {
        portionMode == .overall ? favorite.carbsGrams * factor : detailDrafts.reduce(0) { $0 + $1.scaledCarbsGrams }
    }
    private var currentFat: Double {
        portionMode == .overall ? favorite.fatGrams * factor : detailDrafts.reduce(0) { $0 + $1.scaledFatGrams }
    }
    private var displayCalories: Double {
        portionMode == .overall ? currentCalories : detailDrafts.reduce(0) { $0 + $1.scaledCaloriesKcal }
    }

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
                        modePicker
                        if portionMode == .overall {
                            portionCard
                        } else {
                            detailedIngredientsCard
                        }
                        macroCard
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(favorite.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        Haptics.success()
                        onSave(itemsToSave())
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Gotowe") {
                        isTextInputFocused = false
                    }
                    .font(Tokens.Font.bodyEmphasized)
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
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(displayCalories.rounded())))
                    .font(Tokens.Font.counter)
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                Text(String.localizedStringWithFormat(L("%lld g porcja"), Int(grams)))
                    .font(Tokens.Font.subheadline)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedno zapisane ulubione danie."),
            detailLabel: L("Składniki ulubionego dania osobno."),
            detailCount: max(1, detailDrafts.count)
        )
        .onChange(of: portionMode) { _, newValue in
            if newValue == .detailed {
                syncDetailFromOverall()
            } else {
                grams = detailDrafts.reduce(0) { $0 + $1.quantityGrams }
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
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(grams)))
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.primary)
                        .contentTransition(.numericText())
                }
                Slider(value: $grams, in: range, step: 5) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(Tokens.Palette.primary)
                HStack {
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.lowerBound)))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("Default %lld g"), Int(favorite.defaultQuantityGrams)))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.upperBound)))
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
                    macroPill(label: "Protein", grams: currentProtein, color: Tokens.Palette.primary)
                    macroPill(label: "Węgle", grams: currentCarbs, color: Tokens.Palette.warning)
                    macroPill(label: "Tłuszcz", grams: currentFat, color: Tokens.Palette.accent)
                }
            }
        }
    }

    private var detailedIngredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Składniki")
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Dopasuj zapisany produkt przed dodaniem")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(detailTotalGrams.rounded())))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }

                ForEach($detailDrafts) { $draft in
                    VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                        HStack(spacing: Tokens.Space.xs) {
                            TextField("Produkt", text: $draft.name)
                                .font(Tokens.Font.bodyEmphasized)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTextInputFocused)
                                .submitLabel(.done)
                                .onSubmit { isTextInputFocused = false }
                            productAIButton(for: $draft)
                            if detailDrafts.count > 1 {
                                Button {
                                    detailDrafts.removeAll { $0.id == draft.id }
                                    Haptics.selection()
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundStyle(Tokens.Palette.error)
                                }
                                .buttonStyle(.pressable)
                            }
                        }
                        HStack {
                            Text(
                                String.localizedStringWithFormat(
                                    L("%lld g"),
                                    Int(draft.quantityGrams.rounded())
                                )
                            )
                            .font(Tokens.Font.title3)
                            .foregroundStyle(Tokens.Palette.primary)
                            .contentTransition(.numericText())
                            Spacer()
                            Text(
                                String.localizedStringWithFormat(
                                    L("%lld kcal"),
                                    Int(draft.scaledCaloriesKcal.rounded())
                                )
                            )
                            .font(Tokens.Font.footnote.weight(.bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Slider(value: $draft.quantityGrams, in: 10...1500, step: 5)
                            .tint(Tokens.Palette.primary)
                    }
                }

                Button {
                    detailDrafts.append(FavoriteIngredientDraft(name: "", quantityGrams: 100))
                    Haptics.selection()
                } label: {
                    Label("Dodaj składnik", systemImage: "plus.circle.fill")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .buttonStyle(.pressable)
            }
        }
        .onChange(of: detailDrafts) { _, _ in
            if portionMode == .detailed {
                grams = detailTotalGrams
            }
        }
    }

    private func productAIButton(for draft: Binding<FavoriteIngredientDraft>) -> some View {
        Button {
            isTextInputFocused = false
            Task { await refreshProductNutrition(draft.wrappedValue.id) }
        } label: {
            HStack(spacing: 4) {
                if productLookupsInFlight.contains(draft.wrappedValue.id) {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Tokens.Palette.primary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                }
                AIQuotaBadge(remaining: productNutritionRemaining)
            }
        }
        .frame(minWidth: 32, minHeight: 32)
        .foregroundStyle(Tokens.Palette.primary)
        .background(Circle().fill(Tokens.Palette.primarySoft))
        .buttonStyle(.pressable)
        .disabled(
            productLookupsInFlight.contains(draft.wrappedValue.id)
                || mealAnalyzer == nil
                || draft.wrappedValue.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityLabel(Text("Uzupełnij produkt AI"))
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.productNutritionLookupsPerDay)
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

    private var detailTotalGrams: Double {
        detailDrafts.reduce(0) { $0 + $1.quantityGrams }
    }

    private func syncDetailFromOverall() {
        guard detailDrafts.count == 1 else { return }
        detailDrafts[0].quantityGrams = grams
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
        let completed = await mealAnalyzer.complete(
            item: FoodItem(
                name: trimmed,
                quantityGrams: draft.quantityGrams,
                caloriesKcal: 0,
                proteinGrams: 0,
                carbsGrams: 0,
                fatGrams: 0
            ),
            mealType: QuickDatabaseRootView.suggestedMealType()
        )
        usageMeter?.record(.productNutritionLookup, cap: cap)
        guard let index = detailDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        detailDrafts[index].name = completed.item.name
        detailDrafts[index].baseQuantityGrams = max(1, completed.item.quantityGrams)
        detailDrafts[index].quantityGrams = completed.item.quantityGrams
        detailDrafts[index].caloriesKcal = completed.item.caloriesKcal
        detailDrafts[index].proteinGrams = completed.item.proteinGrams
        detailDrafts[index].carbsGrams = completed.item.carbsGrams
        detailDrafts[index].fatGrams = completed.item.fatGrams
        detailDrafts[index].fiberGrams = completed.item.fiberGrams
        Haptics.success()
    }

    private func itemsToSave() -> [FoodItem] {
        switch portionMode {
        case .overall:
            return [favorite.foodItem(quantityGrams: grams)]
        case .detailed:
            return detailDrafts.compactMap { draft in
                let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedName.isEmpty else { return nil }
                return FoodItem(
                    name: trimmedName,
                    quantityGrams: draft.quantityGrams,
                    caloriesKcal: draft.scaledCaloriesKcal,
                    proteinGrams: draft.scaledProteinGrams,
                    carbsGrams: draft.scaledCarbsGrams,
                    fatGrams: draft.scaledFatGrams,
                    fiberGrams: draft.scaledFiberGrams
                )
            }
        }
    }
}

private struct FavoriteIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var baseQuantityGrams: Double
    var quantityGrams: Double
    var caloriesKcal: Double
    var proteinGrams: Double
    var carbsGrams: Double
    var fatGrams: Double
    var fiberGrams: Double?

    init(
        name: String,
        baseQuantityGrams: Double = 100,
        quantityGrams: Double,
        caloriesKcal: Double = 0,
        proteinGrams: Double = 0,
        carbsGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double? = nil
    ) {
        self.name = name
        self.baseQuantityGrams = baseQuantityGrams
        self.quantityGrams = quantityGrams
        self.caloriesKcal = caloriesKcal
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
    }

    private var factor: Double {
        guard baseQuantityGrams > 0 else { return 1 }
        return quantityGrams / baseQuantityGrams
    }

    var scaledCaloriesKcal: Double { caloriesKcal * factor }
    var scaledProteinGrams: Double { proteinGrams * factor }
    var scaledCarbsGrams: Double { carbsGrams * factor }
    var scaledFatGrams: Double { fatGrams * factor }
    var scaledFiberGrams: Double? { fiberGrams.map { $0 * factor } }
}
