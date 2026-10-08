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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    summaryHero
                    modePicker
                    if portionMode == .overall {
                        nameCard
                        overallCard
                    } else {
                        detailedIngredientsCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background)
            .monoNavigationTitle(recipe.title)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Cancel"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavPill(title: L("Add")) {
                        Task { await commit() }
                    }
                    .disabled(isCompletingNutrition)
                    .opacity(isCompletingNutrition ? 0.45 : 1)
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
                    if mealAnalyzer != nil, aiCompletionUseCount(for: selectedItems) > 0 {
                        AISaveCostNote(remaining: productNutritionRemaining)
                    }
                    MonoButton(
                        title: isCompletingNutrition ? L("Uzupełniam...") : L("Dodaj do dziennika"),
                        kind: .dark,
                        icon: isCompletingNutrition ? "sparkles" : "checkmark"
                    ) {
                        Task { await commit() }
                    }
                    .disabled(isCompletingNutrition)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "book.pages", style: .hi, size: 40)
                MonoLabel(
                    text: L("Przepis") + " · "
                        + String.localizedStringWithFormat(L("%lld g · przed zapisem"), Int(selectedGrams.rounded())),
                    onHero: true
                )
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(selectedCalories.rounded()))")
                    .font(Tokens.Font.monoNumber(60))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            MonoMacroRow(protein: selectedProtein, carbs: selectedCarbs, fat: selectedFat, dark: true)
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

    private var nameCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Nazwa dania"))
            TextField(L("Nazwa przepisu"), text: $overallName)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .focused($isTextInputFocused)
                .submitLabel(.done)
                .onSubmit { isTextInputFocused = false }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Tokens.Mono.line2, lineWidth: 1)
                )
        }
        .monoCard(padding: 16)
    }

    private var overallCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Porcja"))
                Spacer()
                Text(String.localizedStringWithFormat(L("%lld g"), Int(overallGrams.rounded())))
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $overallGrams, in: 10...2500, step: 5)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(String.localizedStringWithFormat(L("%lld g"), 10))
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), 2500))
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
            Text(L("Popraw każdy produkt przed dodaniem"))
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
                MonoButton(title: L("Dodaj składnik"), kind: .outline, icon: "plus", height: 44) {
                    detailDrafts.append(RecipeIngredientDraft(name: "", quantityGrams: 100))
                    Haptics.selection()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .monoRowsCard()
        }
        .onChange(of: detailDrafts) { _, _ in
            if portionMode == .detailed {
                overallGrams = detailTotalGrams
            }
        }
    }

    private func ingredientRow(_ draft: Binding<RecipeIngredientDraft>) -> some View {
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
                        String.localizedStringWithFormat(L("%lld kcal"), Int(draft.wrappedValue.caloriesKcal.rounded()))
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
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.aiActionsPerWeek)
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
        let cap = entitlementsStore?.current.aiActionsPerWeek
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
            Haptics.success()
            return
        }
        let completed = analysis.items.first ?? analysis.overall
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
        onSave(completed)
    }

    /// Save-time completion sends every gap in one request — one AI action.
    private func aiCompletionUseCount(for items: [FoodItem]) -> Int {
        items.contains(where: \.isMissingNutrition) ? 1 : 0
    }

    /// Save-time AI completion spends the meal allowance in overall mode
    /// and the per-product allowance in detailed mode.
    private var aiCompletionQuota: (kind: UsageMeter.Kind, cap: Int?) {
        portionMode == .overall
            ? (.mealAIRefresh, entitlementsStore?.current.aiActionsPerWeek)
            : (.productNutritionLookup, entitlementsStore?.current.aiActionsPerWeek)
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

}
