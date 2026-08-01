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
                        mealTypeCard
                        modePicker
                        if portionMode == .overall {
                            portionAndCaloriesCard
                            macrosCard
                        } else {
                            detailedIngredientsCard
                        }
                        if entitlementsStore?.current.canUseFavorites ?? false {
                            favoriteToggleCard
                        } else if entitlementsStore != nil {
                            favoritePromoCard
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

    private var mealTypeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Posiłek")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Picker("Typ posiłku", selection: $mealType) {
                    Text("Breakfast").tag(MealType.breakfast)
                    Text("Lunch").tag(MealType.lunch)
                    Text("Dinner").tag(MealType.dinner)
                    Text("Snack").tag(MealType.snack)
                }
                .pickerStyle(.segmented)
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

    private var portionAndCaloriesCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                numericRow(
                    NumericRow(
                        symbol: "scalemass",
                        label: "Porcja",
                        range: 1...2000,
                        step: 5,
                        unit: "g"
                    ),
                    value: $quantityGrams
                )
                numericRow(
                    NumericRow(
                        symbol: "flame.fill",
                        label: "Kalorie",
                        range: 0...3000,
                        step: 5,
                        unit: "kcal",
                        tint: Tokens.Palette.warning
                    ),
                    value: $caloriesKcal
                )
            }
        }
    }

    private var macrosCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Makro (opcjonalnie)")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                numericRow(
                    NumericRow(symbol: "fork.knife", label: "Protein", range: 0...300, step: 1, unit: "g"),
                    value: $proteinGrams
                )
                numericRow(
                    NumericRow(symbol: "leaf.fill", label: "Węgle", range: 0...400, step: 1, unit: "g"),
                    value: $carbsGrams
                )
                numericRow(
                    NumericRow(symbol: "drop.fill", label: "Tłuszcz", range: 0...200, step: 1, unit: "g"),
                    value: $fatGrams
                )
                numericRow(
                    NumericRow(symbol: "leaf", label: "Fiber", range: 0...100, step: 1, unit: "g"),
                    value: $fiberGrams
                )
            }
        }
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

    private var favoriteToggleCard: some View {
        Card {
            Toggle(isOn: $saveAsFavorite) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: saveAsFavorite ? "star.fill" : "star")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add to my recipes")
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Szybki ponowny dodatek z karuzeli na Dziś")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
            }
            .tint(Tokens.Palette.primary)
        }
    }

    private var favoritePromoCard: some View {
        Button {
            paywallCoordinator?.present(.favoritesUnavailable)
        } label: {
            Card(background: Tokens.Palette.primarySoft) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Moje przepisy — Premium")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Zapisuj stałe posiłki i dodawaj jednym tapnięciem.")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private struct NumericRow {
        let symbol: String
        let label: LocalizedStringKey
        let range: ClosedRange<Double>
        let step: Double
        let unit: String
        var tint: Color = Tokens.Palette.primary
    }

    private func numericRow(
        _ config: NumericRow,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle().fill(config.tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: config.symbol)
                    .foregroundStyle(config.tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(config.label)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(value.wrappedValue))")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(config.unit)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
            Stepper("", value: value, in: config.range, step: config.step)
                .labelsHidden()
        }
    }

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
            numericRow(
                NumericRow(symbol: "scalemass", label: "Porcja", range: 1...2000, step: 5, unit: "g"),
                value: draft.quantityGrams
            )
            numericRow(
                NumericRow(symbol: "flame.fill", label: "Kalorie", range: 0...3000, step: 5, unit: "kcal"),
                value: draft.caloriesKcal
            )
            numericRow(
                NumericRow(symbol: "fork.knife", label: "Protein", range: 0...300, step: 1, unit: "g"),
                value: draft.proteinGrams
            )
            numericRow(
                NumericRow(symbol: "leaf.fill", label: "Węgle", range: 0...400, step: 1, unit: "g"),
                value: draft.carbsGrams
            )
            numericRow(
                NumericRow(symbol: "drop.fill", label: "Tłuszcz", range: 0...200, step: 1, unit: "g"),
                value: draft.fatGrams
            )
        }
        .onChange(of: draft.wrappedValue) { _, _ in
            syncOverallFromDetail()
        }
    }

    private func productAIButton(for draft: Binding<ManualIngredientDraft>) -> some View {
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
        usageMeter?.record(.mealAIRefresh, cap: cap)
        name = analysis.overall.name
        quantityGrams = analysis.overall.quantityGrams
        caloriesKcal = analysis.overall.caloriesKcal
        proteinGrams = analysis.overall.proteinGrams
        carbsGrams = analysis.overall.carbsGrams
        fatGrams = analysis.overall.fatGrams
        detailDrafts = analysis.items.map {
            ManualIngredientDraft(
                name: $0.name,
                quantityGrams: $0.quantityGrams,
                caloriesKcal: $0.caloriesKcal,
                proteinGrams: $0.proteinGrams,
                carbsGrams: $0.carbsGrams,
                fatGrams: $0.fatGrams
            )
        }
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
        let item = FoodItem(
            name: trimmed,
            quantityGrams: draft.quantityGrams,
            caloriesKcal: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0
        )
        let completed = await mealAnalyzer.complete(item: item, mealType: mealType)
        usageMeter?.record(.productNutritionLookup, cap: cap)
        guard let index = detailDrafts.firstIndex(where: { $0.id == draftID }) else { return }
        detailDrafts[index].name = completed.item.name
        detailDrafts[index].quantityGrams = completed.item.quantityGrams
        detailDrafts[index].caloriesKcal = completed.item.caloriesKcal
        detailDrafts[index].proteinGrams = completed.item.proteinGrams
        detailDrafts[index].carbsGrams = completed.item.carbsGrams
        detailDrafts[index].fatGrams = completed.item.fatGrams
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
        let missingCount = items.filter(Self.needsNutrition).count
        guard missingCount > 0, mealAnalyzer != nil else { return 0 }
        return portionMode == .overall ? 1 : missingCount
    }

    private func canConsumeAICompletion(count: Int) -> Bool {
        guard count > 0 else { return true }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap =
            portionMode == .overall
            ? entitlementsStore?.current.mealAIRefreshesPerDay
            : entitlementsStore?.current.productNutritionLookupsPerDay
        guard let cap, let usageMeter else { return true }
        if usageMeter.used(kind) + count <= cap { return true }
        Haptics.light()
        paywallCoordinator?.present(portionMode == .overall ? .mealAIRefreshQuota : .productNutritionQuota)
        return false
    }

    private func recordAICompletion(count: Int) {
        guard count > 0 else { return }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap =
            portionMode == .overall
            ? entitlementsStore?.current.mealAIRefreshesPerDay
            : entitlementsStore?.current.productNutritionLookupsPerDay
        for _ in 0..<count {
            usageMeter?.record(kind, cap: cap)
        }
    }

    private static func needsNutrition(_ item: FoodItem) -> Bool {
        item.caloriesKcal <= 0 || item.proteinGrams <= 0 || item.carbsGrams <= 0 || item.fatGrams <= 0
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

private struct ManualIngredientDraft: Identifiable, Equatable {
    var id = UUID()
    var name: String = ""
    var quantityGrams: Double = 100
    var caloriesKcal: Double = 200
    var proteinGrams: Double = 10
    var carbsGrams: Double = 20
    var fatGrams: Double = 8
}
