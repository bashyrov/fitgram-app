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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    summaryCard
                    modePicker
                    if portionMode == .overall {
                        portionCard
                    } else {
                        detailedIngredientsCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(favorite.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Add")) { save() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("Gotowe")) {
                        isTextInputFocused = false
                    }
                    .font(Tokens.Font.manrope(15, weight: 800))
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Dodaj do dziennika"), kind: .dark, icon: "checkmark") { save() }
                }
            }
        }
    }

    private func save() {
        Haptics.success()
        onSave(itemsToSave())
    }
}

// MARK: - Sections
extension FavoritePortionSheet {
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "star.fill", style: .hi, size: 40)
                MonoLabel(
                    text: L("Z Twoich przepisów") + " · "
                        + String.localizedStringWithFormat(L("%lld g porcja"), Int(grams.rounded())),
                    onHero: true
                )
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(displayCalories.rounded()))")
                    .font(Tokens.Font.monoNumber(60))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            MonoMacroRow(protein: currentProtein, carbs: currentCarbs, fat: currentFat, dark: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Porcja"))
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(grams)))
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $grams, in: range, step: 5) { editing in
                    if editing { Haptics.selection() }
                }
                .tint(Tokens.Mono.strong)
                HStack {
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.lowerBound)))
                    Spacer()
                    Text(String.localizedStringWithFormat(L("Default %lld g"), Int(favorite.defaultQuantityGrams)))
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(range.upperBound)))
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            Text(L("Dopasuj wagę przed dodaniem"))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
        }
        .monoCard(padding: 16)
    }

    private var detailedIngredientsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Składniki")) {
                HStack(spacing: 8) {
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(detailTotalGrams.rounded())))
                        .font(Tokens.Font.manrope(11, weight: 800))
                        .foregroundStyle(Tokens.Mono.muted)
                    MonoLabel(text: "\(detailDrafts.count)")
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 12)
            .padding(.bottom, 12)
            Text(L("Dopasuj zapisany produkt przed dodaniem"))
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .padding(.horizontal, 6)
                .padding(.top, -4)
                .padding(.bottom, 10)
            AIRequestHint.productNutrition
                .padding(.bottom, 10)

            VStack(spacing: 0) {
                ForEach($detailDrafts) { $draft in
                    if draft.id != detailDrafts.first?.id {
                        Rectangle()
                            .fill(Tokens.Mono.line)
                            .frame(height: 1)
                            .padding(.horizontal, 14)
                    }
                    ingredientRow($draft)
                }
                HStack(spacing: 8) {
                    MonoButton(title: L("Dodaj składnik"), kind: .outline, icon: "plus", height: 44) {
                        detailDrafts.append(FavoriteIngredientDraft(name: "", quantityGrams: 100))
                        Haptics.selection()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .monoRowsCard()
        }
        .onChange(of: detailDrafts) { _, _ in
            if portionMode == .detailed {
                grams = detailTotalGrams
            }
        }
    }

    private func ingredientRow(_ draft: Binding<FavoriteIngredientDraft>) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if detailDrafts.count > 1 {
                Button {
                    let id = draft.wrappedValue.id
                    detailDrafts.removeAll { $0.id == id }
                    Haptics.selection()
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(Tokens.Mono.danger)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(L("Delete")))
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    TextField(L("Produkt"), text: draft.name)
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .focused($isTextInputFocused)
                        .submitLabel(.done)
                        .onSubmit { isTextInputFocused = false }
                    Text(
                        String.localizedStringWithFormat(
                            L("%lld kcal"), Int(draft.wrappedValue.scaledCaloriesKcal.rounded()))
                    )
                    .font(Tokens.Font.manrope(13, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                    productAIButton(for: draft)
                }
                Slider(value: draft.quantityGrams, in: 10...1500, step: 5)
                    .tint(Tokens.Mono.strong)
                Text(String.localizedStringWithFormat(L("%lld g"), Int(draft.wrappedValue.quantityGrams.rounded())))
                    .font(Tokens.Font.manrope(11, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func productAIButton(for draft: Binding<FavoriteIngredientDraft>) -> some View {
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
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.aiActionsPerWeek)
    }

    private var detailTotalGrams: Double {
        detailDrafts.reduce(0) { $0 + $1.quantityGrams }
    }
}

// MARK: - Actions
extension FavoritePortionSheet {
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
        let cap = entitlementsStore?.current.aiActionsPerWeek
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
                FavoriteIngredientDraft(
                    name: item.name,
                    baseQuantityGrams: max(1, item.quantityGrams),
                    quantityGrams: item.quantityGrams,
                    caloriesKcal: item.caloriesKcal,
                    proteinGrams: item.proteinGrams,
                    carbsGrams: item.carbsGrams,
                    fatGrams: item.fatGrams
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
        detailDrafts[index].name = completed.name
        detailDrafts[index].baseQuantityGrams = max(1, completed.quantityGrams)
        detailDrafts[index].quantityGrams = completed.quantityGrams
        detailDrafts[index].caloriesKcal = completed.caloriesKcal
        detailDrafts[index].proteinGrams = completed.proteinGrams
        detailDrafts[index].carbsGrams = completed.carbsGrams
        detailDrafts[index].fatGrams = completed.fatGrams
        detailDrafts[index].fiberGrams = nil
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
