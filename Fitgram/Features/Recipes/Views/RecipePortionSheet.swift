import SwiftUI

/// Final confirmation before a saved recipe is written to the diary.
/// Recipes behave like every non-barcode entry path: the user chooses
/// overall or detailed mode, adjusts grams, optionally completes a
/// product through AI, and only then saves.
struct RecipePortionSheet: View {
    let recipe: Recipe
    let onSave: ([FoodItem]) -> Void
    let onDismiss: () -> Void
    var mealAnalyzer: MealTextAnalysisService?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var usageMeter: UsageMeter?

    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var overallName: String
    @State private var overallGrams: Double
    @State private var detailDrafts: [RecipeIngredientDraft]
    @State private var productLookupsInFlight: Set<UUID> = []
    @State private var isCompletingNutrition = false
    @FocusState private var isTextInputFocused: Bool

    init(
        recipe: Recipe,
        onSave: @escaping ([FoodItem]) -> Void,
        onDismiss: @escaping () -> Void,
        mealAnalyzer: MealTextAnalysisService? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self.recipe = recipe
        self.onSave = onSave
        self.onDismiss = onDismiss
        self.mealAnalyzer = mealAnalyzer
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.usageMeter = usageMeter
        let initialItems = RecipeIngredientDraft.initialDrafts(for: recipe)
        let totalGrams = max(100, initialItems.reduce(0) { $0 + $1.quantityGrams })
        self._overallName = State(initialValue: recipe.title)
        self._overallGrams = State(initialValue: totalGrams)
        self._detailDrafts = State(initialValue: initialItems)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                background
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryHero
                        modePicker
                        if portionMode == .overall {
                            overallCard
                        } else {
                            detailedIngredientsCard
                        }
                        macroCard
                        PrimaryButton(
                            title: isCompletingNutrition ? "Uzupełniam..." : "Dodaj do dziennika",
                            systemImage: isCompletingNutrition ? "sparkles" : "checkmark",
                            isEnabled: !isCompletingNutrition
                        ) {
                            Task { await commit() }
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(recipe.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel"), action: onDismiss)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(L("Gotowe")) {
                        isTextInputFocused = false
                    }
                    .font(Tokens.Font.bodyEmphasized)
                }
            }
        }
        .toastSurface()
    }
}

// MARK: - Sections
extension RecipePortionSheet {
    private var background: some View {
        Tokens.Palette.background
            .ignoresSafeArea()
    }

    private var summaryHero: some View {
        HStack(spacing: Tokens.Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 74, height: 74)
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L("Przepis"))
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(.white.opacity(0.78))
                    .textCase(.uppercase)
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(selectedCalories.rounded())))
                    .font(Tokens.Font.archivo(size: 34, weight: 800, width: 115))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text(String.localizedStringWithFormat(L("%lld g · przed zapisem"), Int(selectedGrams.rounded())))
                    .font(Tokens.Font.manrope(13, weight: 700))
                    .foregroundStyle(.white.opacity(0.82))
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    Tokens.Mono.hero
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 0.35)
        }
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedna pozycja z sumą przepisu."),
            detailLabel: L("Składniki przepisu osobno, z własnymi gramami."),
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

    private var overallCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text(L("Nazwa dania"))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    TextField(L("Nazwa przepisu"), text: $overallName)
                        .font(Tokens.Font.bodyEmphasized)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextInputFocused)
                        .submitLabel(.done)
                        .onSubmit { isTextInputFocused = false }
                }
                HStack {
                    Text(L("Porcja"))
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(overallGrams.rounded())))
                        .font(Tokens.Font.archivo(size: 24, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.primary)
                        .contentTransition(.numericText())
                }
                Slider(value: $overallGrams, in: 10...2500, step: 5)
                    .tint(Tokens.Palette.primary)
            }
        }
    }

    private var detailedIngredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Składniki"))
                            .font(Tokens.Font.headline)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(L("Popraw każdy produkt przed dodaniem"))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(detailTotalGrams.rounded())))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                AIRequestHint.productNutrition

                ForEach($detailDrafts) { $draft in
                    ingredientRow($draft)
                    if draft.id != detailDrafts.last?.id {
                        Divider().background(Tokens.Palette.separator)
                    }
                }

                Button {
                    detailDrafts.append(RecipeIngredientDraft(name: "", quantityGrams: 100))
                    Haptics.selection()
                } label: {
                    Label(L("Dodaj składnik"), systemImage: "plus.circle.fill")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .buttonStyle(.pressable)
            }
        }
        .onChange(of: detailDrafts) { _, _ in
            if portionMode == .detailed {
                overallGrams = detailTotalGrams
            }
        }
    }

    private func ingredientRow(_ draft: Binding<RecipeIngredientDraft>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack(spacing: Tokens.Space.xs) {
                TextField(L("Produkt"), text: draft.name)
                    .font(Tokens.Font.bodyEmphasized)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
                productAIButton(for: draft)
                if detailDrafts.count > 1 {
                    Button {
                        detailDrafts.removeAll { $0.id == draft.wrappedValue.id }
                        Haptics.selection()
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Tokens.Palette.error)
                    }
                    .buttonStyle(.pressable)
                }
            }
            HStack {
                Text(String.localizedStringWithFormat(L("%lld g"), Int(draft.wrappedValue.quantityGrams.rounded())))
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(draft.wrappedValue.caloriesKcal.rounded())))
                    .font(Tokens.Font.footnote.weight(.bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Slider(value: draft.quantityGrams, in: 10...1500, step: 5)
                .tint(Tokens.Palette.primary)
        }
    }

    private func productAIButton(for draft: Binding<RecipeIngredientDraft>) -> some View {
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

    private var macroCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(L("Makro"))
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: L("Protein"), grams: selectedProtein, color: Tokens.Palette.primary)
                    macroPill(label: L("Węgle"), grams: selectedCarbs, color: Tokens.Palette.warning)
                    macroPill(label: L("Tłuszcz"), grams: selectedFat, color: Tokens.Palette.accent)
                }
            }
        }
    }

    private func macroPill(label: String, grams: Double, color: Color) -> some View {
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
}

// MARK: - Portion math
extension RecipePortionSheet {
    private var detailTotalGrams: Double {
        detailDrafts.reduce(0) { $0 + $1.quantityGrams }
    }

    private var selectedItems: [FoodItem] {
        switch portionMode {
        case .overall:
            let base = detailItems
            let baseGrams = max(1, base.reduce(0) { $0 + $1.quantityGrams })
            let factor = overallGrams / baseGrams
            return [
                FoodItem(
                    name: overallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? recipe.title
                        : overallName,
                    quantityGrams: overallGrams,
                    caloriesKcal: base.reduce(0) { $0 + $1.caloriesKcal } * factor,
                    proteinGrams: base.reduce(0) { $0 + $1.proteinGrams } * factor,
                    carbsGrams: base.reduce(0) { $0 + $1.carbsGrams } * factor,
                    fatGrams: base.reduce(0) { $0 + $1.fatGrams } * factor,
                    confidence: 1.0
                )
            ]
        case .detailed:
            return detailItems
        }
    }

    private var detailItems: [FoodItem] {
        detailDrafts.compactMap { draft in
            let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            return FoodItem(
                name: trimmed,
                quantityGrams: draft.quantityGrams,
                caloriesKcal: draft.caloriesKcal,
                proteinGrams: draft.proteinGrams,
                carbsGrams: draft.carbsGrams,
                fatGrams: draft.fatGrams,
                confidence: 1.0
            )
        }
    }

    private var selectedCalories: Double { selectedItems.reduce(0) { $0 + $1.caloriesKcal } }
    private var selectedProtein: Double { selectedItems.reduce(0) { $0 + $1.proteinGrams } }
    private var selectedCarbs: Double { selectedItems.reduce(0) { $0 + $1.carbsGrams } }
    private var selectedFat: Double { selectedItems.reduce(0) { $0 + $1.fatGrams } }
    private var selectedGrams: Double { selectedItems.reduce(0) { $0 + $1.quantityGrams } }
}

// MARK: - Actions
extension RecipePortionSheet {
    private func syncDetailFromOverall() {
        guard detailDrafts.count == 1 else { return }
        detailDrafts[0].quantityGrams = overallGrams
    }

    private func syncOverallFromDetail() {
        overallGrams = detailTotalGrams
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
        let mealType = RecipeRepository.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
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
                return RecipeIngredientDraft(
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

    private func commit() async {
        let draftItems = selectedItems
        guard let mealAnalyzer else {
            onSave(draftItems)
            return
        }
        let completionUse = aiCompletionUseCount(for: draftItems)
        guard canConsumeAICompletion(count: completionUse) else { return }
        isCompletingNutrition = true
        defer { isCompletingNutrition = false }
        let completed = await mealAnalyzer.complete(
            items: draftItems,
            mealType: RecipeRepository.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date()))
        )
        recordAICompletion(count: completionUse)
        onSave(completed)
    }

    private func aiCompletionUseCount(for items: [FoodItem]) -> Int {
        let missingCount = items.filter(\.isMissingNutrition).count
        guard missingCount > 0 else { return 0 }
        return portionMode == .overall ? 1 : missingCount
    }

    /// Save-time AI completion spends the meal allowance in overall mode
    /// and the per-product allowance in detailed mode.
    private var aiCompletionQuota: (kind: UsageMeter.Kind, cap: Int?) {
        portionMode == .overall
            ? (.mealAIRefresh, entitlementsStore?.current.mealAIRefreshesPerDay)
            : (.productNutritionLookup, entitlementsStore?.current.productNutritionLookupsPerDay)
    }

    private func canConsumeAICompletion(count: Int) -> Bool {
        guard count > 0 else { return true }
        let (kind, cap) = aiCompletionQuota
        guard let cap, let usageMeter else { return true }
        if usageMeter.used(kind) + count <= cap { return true }
        Haptics.light()
        paywallCoordinator?.present(portionMode == .overall ? .mealAIRefreshQuota : .productNutritionQuota)
        return false
    }

    private func recordAICompletion(count: Int) {
        guard count > 0 else { return }
        let (kind, cap) = aiCompletionQuota
        for _ in 0..<count {
            usageMeter?.record(kind, cap: cap)
        }
    }

}
