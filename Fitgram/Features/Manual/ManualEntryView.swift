import OSLog
import SwiftUI

/// Manual meal entry — name + portion + macros. The escape hatch for
/// foods that aren't in the catalog, didn't come from a scan, and don't
/// fit any other entry path. Source flag = `.manual` so calibration +
/// AI confidence don't touch the saved row.
struct ManualEntryView: View {  // swiftlint:disable:this type_body_length
    let mealSaver: any MealSaving
    let userRemoteID: String
    let favoritesService: (any FavoritesServing)?
    let entitlementsStore: EntitlementsStore?
    let paywallCoordinator: PaywallCoordinator?
    let usageMeter: UsageMeter?
    let mealAnalyzer: MealTextAnalysisService?
    let onDismiss: () -> Void

    @State private var name: String = ""
    @State private var quantityGrams: Double = 100
    @State private var caloriesKcal: Double = 0
    @State private var proteinGrams: Double = 0
    @State private var carbsGrams: Double = 0
    @State private var fatGrams: Double = 0
    @State private var fiberGrams: Double = 0
    @State private var mealType: MealType = ManualEntryView.inferDefaultMealType()
    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var isAnalyzingText = false
    @State private var isCompletingNutrition = false
    @State private var productLookupsInFlight: Set<UUID> = []
    @State private var detailDrafts: [ManualIngredientDraft] = [
        ManualIngredientDraft(
            name: "", quantityGrams: 100, caloriesKcal: 0, proteinGrams: 0, carbsGrams: 0, fatGrams: 0)
    ]
    @State private var saveAsFavorite: Bool = false
    @State private var error: String?
    @FocusState private var isTextInputFocused: Bool

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && quantityGrams > 0 && !isCompletingNutrition
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        nameCard
                        ManualMealTypeCard(mealType: $mealType)
                        modePicker
                        if portionMode == .overall {
                            ManualPortionCard(quantityGrams: $quantityGrams, caloriesKcal: $caloriesKcal)
                            ManualMacrosCard(
                                proteinGrams: $proteinGrams,
                                carbsGrams: $carbsGrams,
                                fatGrams: $fatGrams,
                                fiberGrams: $fiberGrams
                            )
                        } else {
                            detailedIngredientsCard
                        }
                        if entitlementsStore?.current.canUseFavorites ?? false {
                            ManualFavoriteToggleCard(isOn: $saveAsFavorite)
                        } else if entitlementsStore != nil {
                            ManualFavoritePromoCard {
                                paywallCoordinator?.present(.favoritesUnavailable)
                            }
                        }
                        if let error {
                            Text(error)
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.error)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text("Wpisz posiłek"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isCompletingNutrition {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave)
                    .font(Tokens.Font.bodyEmphasized)
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
        .toastSurface()
    }

    // MARK: - Cards

    private var nameCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Nazwa")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                HStack(spacing: Tokens.Space.sm) {
                    Text("Wpisz danie i odśwież dane z AI")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer(minLength: 0)
                    aiRefreshButton
                }
                AIRequestHint.mealRefresh
                TextField("np. Naleśniki z serem", text: $name)
                    .font(Tokens.Font.body)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
            }
        }
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedna pozycja z ręcznie wpisaną wagą i makro."),
            detailLabel: L("Lista produktów, każdy z własną gramaturą."),
            detailCount: max(1, detailDrafts.count)
        )
    }

    private var detailedIngredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text("Składniki")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String.localizedStringWithFormat(L("%lld g"), Int(detailTotalGrams.rounded())))
                        .font(Tokens.Font.footnote.weight(.bold))
                        .foregroundStyle(Tokens.Palette.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Tokens.Palette.primarySoft))
                }
                AIRequestHint.productNutrition

                ForEach($detailDrafts) { $draft in
                    ingredientDraftRow($draft)
                    if draft.id != detailDrafts.last?.id {
                        Divider().background(Tokens.Palette.separator)
                    }
                }

                Button {
                    detailDrafts.append(ManualIngredientDraft())
                    Haptics.selection()
                } label: {
                    Label("Dodaj składnik", systemImage: "plus.circle.fill")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .buttonStyle(.pressable)
            }
        }
    }

    // MARK: - Helpers

    private func ingredientDraftRow(_ draft: Binding<ManualIngredientDraft>) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                TextField("Składnik", text: draft.name)
                    .font(Tokens.Font.bodyEmphasized)
                    .textFieldStyle(.roundedBorder)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
                productAIButton(for: draft)
                if detailDrafts.count > 1 {
                    Button {
                        detailDrafts.removeAll { $0.id == draft.wrappedValue.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(Tokens.Palette.error)
                    }
                    .buttonStyle(.pressable)
                }
            }
            ManualNumericRow(
                config: .init(symbol: "scalemass", label: "Porcja", range: 1...2000, step: 5, unit: "g"),
                value: draft.quantityGrams
            )
            ManualNumericRow(
                config: .init(symbol: "flame.fill", label: "Kalorie", range: 0...3000, step: 5, unit: "kcal"),
                value: draft.caloriesKcal
            )
            ManualNumericRow(
                config: .init(symbol: "fork.knife", label: "Protein", range: 0...300, step: 1, unit: "g"),
                value: draft.proteinGrams
            )
            ManualNumericRow(
                config: .init(symbol: "leaf.fill", label: "Węgle", range: 0...400, step: 1, unit: "g"),
                value: draft.carbsGrams
            )
            ManualNumericRow(
                config: .init(symbol: "drop.fill", label: "Tłuszcz", range: 0...200, step: 1, unit: "g"),
                value: draft.fatGrams
            )
        }
        .onChange(of: draft.wrappedValue) { _, _ in
            syncOverallFromDetail()
        }
    }

    private func productAIButton(for draft: Binding<ManualIngredientDraft>) -> some View {
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

    private var aiRefreshButton: some View {
        Button {
            isTextInputFocused = false
            Task { await refreshFromAI() }
        } label: {
            HStack(spacing: 5) {
                if isAnalyzingText {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Tokens.Palette.primary)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                }
                Text("Odśwież AI")
                    .font(Tokens.Font.caption.weight(.bold))
                AIQuotaBadge(remaining: mealAIRefreshRemaining)
            }
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Tokens.Palette.primarySoft))
        }
        .buttonStyle(.pressable)
        .disabled(
            isAnalyzingText || mealAnalyzer == nil || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
    }

    private var mealAIRefreshRemaining: Int? {
        usageMeter?.remaining(.mealAIRefresh, cap: entitlementsStore?.current.mealAIRefreshesPerDay)
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.productNutritionLookupsPerDay)
    }

    private func refreshFromAI() async {
        guard let mealAnalyzer else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let cap = entitlementsStore?.current.mealAIRefreshesPerDay
        if usageMeter?.canUse(.mealAIRefresh, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.mealAIRefreshQuota)
            return
        }
        isAnalyzingText = true
        defer { isAnalyzingText = false }
        let analysis = await mealAnalyzer.analyze(text: trimmed, mealType: mealType)
        if analysis.aiSucceeded {
            usageMeter?.record(.mealAIRefresh, cap: cap)
        }
        name = analysis.overall.name
        quantityGrams = analysis.overall.quantityGrams
        caloriesKcal = analysis.overall.caloriesKcal
        proteinGrams = analysis.overall.proteinGrams
        carbsGrams = analysis.overall.carbsGrams
        fatGrams = analysis.overall.fatGrams
        detailDrafts = analysis.items.map(ManualIngredientDraft.init(detected:))
        Haptics.success()
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
        let analysis = await mealAnalyzer.analyze(
            text: "\(Int(draft.quantityGrams.rounded())) g \(trimmed)",
            mealType: mealType,
            quotaKind: .productNutrition
        )
        if analysis.items.count > 1,
            let index = detailDrafts.firstIndex(where: { $0.id == draftID })
        {
            detailDrafts.replaceSubrange(
                index...index, with: analysis.items.map(ManualIngredientDraft.init(detected:)))
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
        detailDrafts[index].quantityGrams = completed.quantityGrams
        detailDrafts[index].caloriesKcal = completed.caloriesKcal
        detailDrafts[index].proteinGrams = completed.proteinGrams
        detailDrafts[index].carbsGrams = completed.carbsGrams
        detailDrafts[index].fatGrams = completed.fatGrams
        Haptics.success()
    }

    private func save() async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isCompletingNutrition = true
        defer { isCompletingNutrition = false }
        let draftItems = itemsToSave(defaultName: trimmed)
        let completionUse = aiCompletionUseCount(for: draftItems)
        guard canConsumeAICompletion(count: completionUse) else { return }
        let items = await mealAnalyzer?.complete(items: draftItems, mealType: mealType) ?? draftItems
        recordAICompletion(count: completionUse)
        let meal = MealEntry(
            mealType: mealType,
            source: .manual,
            items: items
        )
        do {
            try mealSaver.save(meal: meal)
            if let favoritesService = favoriteServiceForSave {
                try? favoritesService.add(
                    FavoriteMeal(
                        userRemoteID: userRemoteID,
                        name: trimmed,
                        defaultQuantityGrams: items.reduce(0) { $0 + $1.quantityGrams },
                        caloriesKcal: items.reduce(0) { $0 + $1.caloriesKcal },
                        proteinGrams: items.reduce(0) { $0 + $1.proteinGrams },
                        carbsGrams: items.reduce(0) { $0 + $1.carbsGrams },
                        fatGrams: items.reduce(0) { $0 + $1.fatGrams },
                        fiberGrams: fiberGrams > 0 ? fiberGrams : nil,
                        source: .manual
                    )
                )
            }
            Haptics.success()
            onDismiss()
        } catch {
            Logger.persistence.error("Manual save failed: \(String(describing: error))")
            self.error = L("Couldn't save. Try again.")
        }
    }

    private var favoriteServiceForSave: (any FavoritesServing)? {
        guard saveAsFavorite, entitlementsStore?.current.canUseFavorites ?? false else {
            return nil
        }
        return favoritesService
    }

    private var detailTotalGrams: Double {
        detailDrafts.reduce(0) { $0 + $1.quantityGrams }
    }

    private func syncOverallFromDetail() {
        guard portionMode == .detailed else { return }
        quantityGrams = detailDrafts.reduce(0) { $0 + $1.quantityGrams }
        caloriesKcal = detailDrafts.reduce(0) { $0 + $1.caloriesKcal }
        proteinGrams = detailDrafts.reduce(0) { $0 + $1.proteinGrams }
        carbsGrams = detailDrafts.reduce(0) { $0 + $1.carbsGrams }
        fatGrams = detailDrafts.reduce(0) { $0 + $1.fatGrams }
    }

    private func itemsToSave(defaultName: String) -> [FoodItem] {
        switch portionMode {
        case .overall:
            return [
                FoodItem(
                    name: defaultName,
                    quantityGrams: quantityGrams,
                    caloriesKcal: caloriesKcal,
                    proteinGrams: proteinGrams,
                    carbsGrams: carbsGrams,
                    fatGrams: fatGrams,
                    fiberGrams: fiberGrams > 0 ? fiberGrams : nil
                )
            ]
        case .detailed:
            return detailDrafts.enumerated().map { index, draft in
                FoodItem(
                    name: draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "\(defaultName) \(index + 1)"
                        : draft.name,
                    quantityGrams: draft.quantityGrams,
                    caloriesKcal: draft.caloriesKcal,
                    proteinGrams: draft.proteinGrams,
                    carbsGrams: draft.carbsGrams,
                    fatGrams: draft.fatGrams
                )
            }
        }
    }

    private func aiCompletionUseCount(for items: [FoodItem]) -> Int {
        let missingCount = items.filter(\.isMissingNutrition).count
        guard missingCount > 0, mealAnalyzer != nil else { return 0 }
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

    /// Best guess of which meal-type slot the entry belongs to, based
    /// on the time of day.
    private static func inferDefaultMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<15: return .lunch
        case 17..<22: return .dinner
        default: return .snack
        }
    }
}
