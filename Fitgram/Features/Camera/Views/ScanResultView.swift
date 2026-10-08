import SwiftUI

// swiftlint:disable file_length
// Detected items + portion adjustment + save. Items can be tapped to
// edit, swiped to delete, or added manually via the footer. The portion
// slider scales totals globally.
// swiftlint:disable:next type_body_length
struct ScanResultView: View {
    let initialResult: ScanResult
    let imageData: Data?
    let onSave: (ScanResult, Double) -> Void
    let onRetake: () -> Void
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    @State private var result: ScanResult
    @State private var portionMode: PortionAdjustmentMode = .overall
    @State private var overallName: String
    @State private var overallGrams: Double
    @State private var detailGrams: [UUID: Double] = [:]
    @State private var editorMode: FoodItemEditorSheet.Mode?
    @State private var isAnalyzingText = false
    @State private var isCompletingNutrition = false
    @State private var productLookupsInFlight: Set<UUID> = []
    @FocusState private var isTextInputFocused: Bool

    init(
        result: ScanResult,
        imageData: Data?,
        onSave: @escaping (ScanResult, Double) -> Void,
        onRetake: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        favoritesService: (any FavoritesServing)? = nil,
        entitlementsStore: EntitlementsStore? = nil,
        paywallCoordinator: PaywallCoordinator? = nil,
        userRemoteID: String? = nil,
        mealAnalyzer: MealTextAnalysisService? = nil,
        usageMeter: UsageMeter? = nil
    ) {
        self.initialResult = result
        self.imageData = imageData
        self.onSave = onSave
        self.onRetake = onRetake
        self.onDismiss = onDismiss
        self.favoritesService = favoritesService
        self.entitlementsStore = entitlementsStore
        self.paywallCoordinator = paywallCoordinator
        self.userRemoteID = userRemoteID
        self.mealAnalyzer = mealAnalyzer
        self.usageMeter = usageMeter
        self._result = State(initialValue: result)
        self._overallName = State(initialValue: Self.defaultOverallName(for: result))
        self._overallGrams = State(initialValue: Self.totalGrams(for: result.items))
    }

    var body: some View {
        VStack(spacing: 0) {
            AddFlowNavBar(
                title: TL(
                    pl: "Wynik skanu", en: "Scan result", uk: "Результат сканування",
                    ru: "Результат сканирования", es: "Resultado del escaneo"
                ),
                onLeft: onDismiss
            ) {
                MonoNavPill(title: L("Gotowe")) {
                    Task { await saveSelectedResult() }
                }
                .disabled(isCompletingNutrition)
            }
            ScrollView {
                contentStack
            }
        }
        .background(Tokens.Palette.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) { footer }
        .sheet(item: $editorMode) { mode in
            FoodItemEditorSheet(
                mode: mode,
                onCommit: { item in apply(edited: item, mode: mode) },
                onDismiss: { editorMode = nil }
            )
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gotowe") {
                    isTextInputFocused = false
                }
                .font(Tokens.Font.bodyEmphasized)
            }
        }
    }

    /// Mockup order: photo · total hero · portion mode · "Co widzimy" · mode content.
    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            photoCard
                .padding(.top, 4)
            summaryCard
            modePicker
            seenCard
            if portionMode == .overall {
                overallCard
            } else {
                itemsSection
            }
            favoriteButton
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, 20)
    }

    private func apply(edited item: ScanResult.DetectedItem, mode: FoodItemEditorSheet.Mode) {
        switch mode {
        case .adding:
            result.items.append(item)
            detailGrams[item.id] = item.quantityGrams
        case .editing(let original):
            if let index = result.items.firstIndex(where: { $0.id == original.id }) {
                result.items[index] = item
                detailGrams[item.id] = item.quantityGrams
            }
        }
        if overallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            overallName = Self.defaultOverallName(for: result)
        }
    }

    /// `placeholder_img(170, 'Twoje zdjęcie', 22)` — the captured photo when we have it.
    @ViewBuilder
    private var photoCard: some View {
        if let imageData, let image = UIImage(data: imageData) {
            Color.clear
                .frame(height: 170)
                .frame(maxWidth: .infinity)
                .overlay(
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Tokens.Mono.line, lineWidth: 1)
                )
                .accessibilityHidden(true)
        } else {
            MonoImagePlaceholder(
                height: 170,
                label: TL(pl: "Twoje zdjęcie", en: "Your photo", uk: "Твоє фото", ru: "Твоё фото", es: "Tu foto")
            )
        }
    }

    private var summaryCard: some View {
        AddFlowTotalHero(
            icon: "camera",
            caption: L("Posiłek") + " · " + mealTypeLabel(for: result.suggestedMealType),
            kcal: selectedCalories,
            protein: selectedProtein,
            carbs: selectedCarbs,
            fat: selectedFat
        ) {
            confidenceBadge
        }
    }

    private var modePicker: some View {
        PortionModeSelector(
            selection: $portionMode,
            totalLabel: L("Jedno danie z wagą i sumą makro."),
            detailLabel: L("Składniki z osobną gramaturą."),
            detailCount: max(1, result.items.count)
        )
    }

    /// "Co widzimy": recognised items as track chips (name + confidence). Tap a chip to edit it.
    private var seenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Co widzimy"))
                Spacer(minLength: 8)
                Text(String.localizedStringWithFormat(L("%lld elementów"), result.items.count))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            ScanChipFlowLayout(spacing: 6) {
                ForEach(result.items) { item in
                    Button {
                        editorMode = .editing(item)
                    } label: {
                        HStack(spacing: 6) {
                            Text(item.name.isEmpty ? L("Produkt") : item.name)
                                .font(Tokens.Font.manrope(13, weight: 700))
                                .foregroundStyle(Tokens.Palette.ink)
                                .lineLimit(1)
                            Text(verbatim: "\(Int((item.confidence * 100).rounded()))%")
                                .font(Tokens.Font.manrope(13, weight: 600))
                                .foregroundStyle(Tokens.Mono.muted)
                        }
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(Tokens.Mono.track))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .monoCard(padding: 16)
    }

    private var overallCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddFlowNameCard(label: L("Nazwa dania")) {
                TextField("Risotto z krewetkami", text: $overallName)
                    .focused($isTextInputFocused)
                    .submitLabel(.done)
                    .onSubmit { isTextInputFocused = false }
            } action: {
                aiRefreshButton(text: overallName)
            }
            AIRequestHint.mealRefresh
            AddFlowPortionCard(
                grams: $overallGrams,
                range: 10...1500,
                step: 5,
                note: String(format: "×%.2f", overallFactor)
            )
            MonoHint(text: L("Szczegóły są pod spodem, ale do dziennika trafi jedna pozycja."))
        }
    }

    @ViewBuilder
    private var favoriteButton: some View {
        if let context = favoriteContext, let first = result.items.first {
            let name =
                result.items.count > 1
                ? result.items.map(\.name).joined(separator: " + ")
                : first.name
            FavoriteToggleButton(
                payload: FavoriteToggleButton.Payload(
                    name: name,
                    quantityGrams: selectedGrams,
                    caloriesKcal: selectedCalories,
                    proteinGrams: selectedProtein,
                    carbsGrams: selectedCarbs,
                    fatGrams: selectedFat,
                    fiberGrams: nil,
                    source: .photoScan,
                    catalogFoodID: nil
                ),
                userRemoteID: context.userRemoteID,
                favoritesService: context.favoritesService,
                entitlementsStore: context.entitlementsStore,
                paywallCoordinator: context.paywallCoordinator
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
        }
    }

    private var favoriteContext: ScanResultFavoriteContext? {
        guard let favoritesService, let entitlementsStore, let paywallCoordinator, let userRemoteID else {
            return nil
        }
        return ScanResultFavoriteContext(
            favoritesService: favoritesService,
            entitlementsStore: entitlementsStore,
            paywallCoordinator: paywallCoordinator,
            userRemoteID: userRemoteID
        )
    }

    /// `ingr_list(ING)`: "Składniki" header + rows with sliders + "Dodaj składnik" / "Uzupełnij AI".
    private var itemsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            AddFlowIngredientsSection(
                title: L("Składniki"),
                count: result.items.count,
                sub: L("Edytuj gramaturę produktu przed zapisem")
            ) {
                ForEach(Array(result.items.enumerated()), id: \.element.id) { index, item in
                    itemRow(item, showsDivider: index > 0)
                        .contentShape(Rectangle())
                        .onTapGesture { editorMode = .editing(item) }
                        .contextMenu {
                            Button {
                                editorMode = .editing(item)
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                result.items.removeAll(where: { $0.id == item.id })
                                detailGrams[item.id] = nil
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            } footer: {
                MonoButton(title: L("Dodaj produkt"), kind: .outline, icon: "plus", height: 44) {
                    let item = ScanResult.DetectedItem(
                        name: "",
                        quantityGrams: 100,
                        caloriesKcal: 0,
                        proteinGrams: 0,
                        carbsGrams: 0,
                        fatGrams: 0,
                        confidence: 1.0
                    )
                    result.items.append(item)
                    detailGrams[item.id] = item.quantityGrams
                    Haptics.selection()
                }
                .accessibilityIdentifier(A11yID.Scan.addItem)
                AddFlowAIButton(
                    title: AddFlowCopy.fillWithAI,
                    isLoading: isAnalyzingText,
                    remaining: mealAIRefreshRemaining,
                    showsQuota: false,
                    height: 44,
                    fullWidth: true,
                    isDisabled: isAnalyzingText || mealAnalyzer == nil || itemNamesText.isEmpty
                ) {
                    isTextInputFocused = false
                    let text = itemNamesText
                    Task { await refreshFromAI(text: text) }
                }
            }
            AIRequestHint.productNutrition
        }
    }

    private var itemNamesText: String {
        result.items.map(\.name).joined(separator: ", ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func itemRow(_ item: ScanResult.DetectedItem, showsDivider: Bool) -> some View {
        let binding = gramsBinding(for: item)
        let name = nameBinding(for: item)
        let factor = item.quantityGrams > 0 ? binding.wrappedValue / item.quantityGrams : 1
        var removeAction: (() -> Void)?
        if result.items.count > 1 {
            removeAction = {
                result.items.removeAll(where: { $0.id == item.id })
                detailGrams[item.id] = nil
            }
        }
        return AddFlowIngredientRow(
            showsDivider: showsDivider,
            kcal: item.caloriesKcal * factor,
            grams: binding,
            range: 10...800,
            step: 5,
            onRemove: removeAction
        ) {
            TextField("Produkt", text: name)
                .focused($isTextInputFocused)
                .submitLabel(.done)
                .onSubmit { isTextInputFocused = false }
        } accessory: {
            productAIButton(for: item)
        }
    }

    /// Edited grams for one detected item, defaulting to the AI estimate.
    private func gramsBinding(for item: ScanResult.DetectedItem) -> Binding<Double> {
        Binding<Double>(
            get: { detailGrams[item.id] ?? item.quantityGrams },
            set: { detailGrams[item.id] = $0 }
        )
    }

    /// Edits the item's name in place; the other fields keep their values.
    private func nameBinding(for item: ScanResult.DetectedItem) -> Binding<String> {
        Binding<String>(
            get: {
                guard let index = result.items.firstIndex(where: { $0.id == item.id }) else { return item.name }
                return result.items[index].name
            },
            set: { newValue in
                guard let index = result.items.firstIndex(where: { $0.id == item.id }) else { return }
                result.items[index] = ScanResult.DetectedItem(
                    id: item.id,
                    name: newValue,
                    quantityGrams: result.items[index].quantityGrams,
                    caloriesKcal: result.items[index].caloriesKcal,
                    proteinGrams: result.items[index].proteinGrams,
                    carbsGrams: result.items[index].carbsGrams,
                    fatGrams: result.items[index].fatGrams,
                    confidence: result.items[index].confidence
                )
            }
        )
    }

    private func productAIButton(for item: ScanResult.DetectedItem) -> some View {
        AIProductLookupButton(
            isLoading: productLookupsInFlight.contains(item.id),
            remaining: productNutritionRemaining,
            isDisabled: productLookupsInFlight.contains(item.id)
                || mealAnalyzer == nil
                || item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            accessibilityLabel: L("Uzupełnij produkt AI")
        ) {
            Task { await refreshProductNutrition(item) }
        }
    }

    private var confidenceBadge: some View {
        let pct = Int(result.confidence * 100)
        return Text(String.localizedStringWithFormat(L("%lld%% confidence"), pct))
            .font(Tokens.Font.manrope(11, weight: 800))
            .foregroundStyle(Tokens.Mono.onHi)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Capsule().fill(Tokens.Mono.hi))
    }

    /// `bottom(btn('Dodaj do dziennika', dark, check) + btn('Zrób kolejne zdjęcie', outline, camera))`.
    private var footer: some View {
        MonoBottomBar {
            MonoButton(
                title: isCompletingNutrition ? L("Uzupełniam...") : L("Dodaj do dziennika"),
                kind: .dark,
                icon: isCompletingNutrition ? "sparkles" : "checkmark"
            ) {
                Task { await saveSelectedResult() }
            }
            .disabled(isCompletingNutrition)
            MonoButton(title: L("Take another"), kind: .outline, icon: "camera", action: onRetake)
        }
    }

    private func saveSelectedResult() async {
        let selected = selectedResult
        guard let mealAnalyzer else {
            onSave(selected, 1)
            return
        }
        let completionUse = aiCompletionUseCount(for: selected.items)
        guard canConsumeAICompletion(count: completionUse) else { return }
        isCompletingNutrition = true
        defer { isCompletingNutrition = false }
        let completed = await mealAnalyzer.complete(result: selected)
        recordAICompletion(count: completionUse)
        onSave(completed, 1)
    }

    private func aiRefreshButton(text: String) -> some View {
        AddFlowAIButton(
            isLoading: isAnalyzingText,
            remaining: mealAIRefreshRemaining,
            isDisabled: isAnalyzingText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        ) {
            isTextInputFocused = false
            Task { await refreshFromAI(text: text) }
        }
    }

    private var mealAIRefreshRemaining: Int? {
        usageMeter?.remaining(.mealAIRefresh, cap: entitlementsStore?.current.aiActionsPerWeek)
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.aiActionsPerWeek)
    }

    private func refreshFromAI(text: String) async {
        guard let mealAnalyzer else { return }
        let cap = entitlementsStore?.current.aiActionsPerWeek
        if usageMeter?.canUse(.mealAIRefresh, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.mealAIRefreshQuota)
            return
        }
        isAnalyzingText = true
        defer { isAnalyzingText = false }
        let analysis = await mealAnalyzer.analyze(text: text, mealType: result.suggestedMealType)
        if analysis.aiSucceeded {
            usageMeter?.record(.mealAIRefresh, cap: cap)
        }
        result = analysis.detailedResult
        overallName = analysis.overall.name
        overallGrams = analysis.overall.quantityGrams
        detailGrams = Dictionary(uniqueKeysWithValues: result.items.map { ($0.id, $0.quantityGrams) })
        Haptics.success()
    }

    private func refreshProductNutrition(_ item: ScanResult.DetectedItem) async {
        guard let mealAnalyzer else { return }
        let currentGrams = detailGrams[item.id] ?? item.quantityGrams
        guard currentGrams > 0, !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let cap = entitlementsStore?.current.aiActionsPerWeek
        if usageMeter?.canUse(.productNutritionLookup, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.productNutritionQuota)
            return
        }
        productLookupsInFlight.insert(item.id)
        defer { productLookupsInFlight.remove(item.id) }
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let analysis = await mealAnalyzer.analyze(
            text: "\(Int(currentGrams.rounded())) g \(trimmed)",
            mealType: result.suggestedMealType,
            quotaKind: .productNutrition
        )
        if analysis.items.count > 1,
            let index = result.items.firstIndex(where: { $0.id == item.id })
        {
            let replacement = analysis.items.map { aiItem in
                ScanResult.DetectedItem(
                    id: aiItem.id,
                    name: aiItem.name,
                    quantityGrams: aiItem.quantityGrams,
                    caloriesKcal: aiItem.caloriesKcal,
                    proteinGrams: aiItem.proteinGrams,
                    carbsGrams: aiItem.carbsGrams,
                    fatGrams: aiItem.fatGrams,
                    confidence: aiItem.confidence
                )
            }
            result.items.replaceSubrange(index...index, with: replacement)
            detailGrams[item.id] = nil
            for replacementItem in replacement {
                detailGrams[replacementItem.id] = replacementItem.quantityGrams
            }
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
        guard let index = result.items.firstIndex(where: { $0.id == item.id }) else { return }
        result.items[index] = ScanResult.DetectedItem(
            id: item.id,
            name: completed.name,
            quantityGrams: completed.quantityGrams,
            caloriesKcal: completed.caloriesKcal,
            proteinGrams: completed.proteinGrams,
            carbsGrams: completed.carbsGrams,
            fatGrams: completed.fatGrams,
            confidence: completed.confidence
        )
        detailGrams[item.id] = completed.quantityGrams
        Haptics.success()
    }

    // MARK: - Helpers

    private func mealTypeLabel(for kind: MealType) -> String {
        switch kind {
        case .breakfast: return L("Breakfast")
        case .lunch: return L("Lunch")
        case .dinner: return L("Dinner")
        case .snack: return L("Snack")
        }
    }

    private var adjustedProtein: Double { result.totalProtein }
    private var adjustedCarbs: Double { result.totalCarbs }
    private var adjustedFat: Double { result.totalFat }

    private var selectedResult: ScanResult {
        switch portionMode {
        case .overall:
            return ScanResult(
                items: [overallItem],
                suggestedMealType: result.suggestedMealType,
                confidence: result.confidence,
                rawAINotes: result.rawAINotes
            )
        case .detailed:
            return ScanResult(
                items: detailedItems,
                suggestedMealType: result.suggestedMealType,
                confidence: result.confidence,
                rawAINotes: result.rawAINotes
            )
        }
    }

    private var overallItem: ScanResult.DetectedItem {
        ScanResult.DetectedItem(
            name: overallName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Self.defaultOverallName(for: result)
                : overallName,
            quantityGrams: overallGrams,
            caloriesKcal: result.totalCalories * overallFactor,
            proteinGrams: result.totalProtein * overallFactor,
            carbsGrams: result.totalCarbs * overallFactor,
            fatGrams: result.totalFat * overallFactor,
            confidence: result.confidence
        )
    }

    private var detailedItems: [ScanResult.DetectedItem] {
        result.items.compactMap { item in
            let trimmedName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty else { return nil }
            let grams = detailGrams[item.id] ?? item.quantityGrams
            let factor = item.quantityGrams > 0 ? grams / item.quantityGrams : 1
            return ScanResult.DetectedItem(
                id: item.id,
                name: trimmedName,
                quantityGrams: grams,
                caloriesKcal: item.caloriesKcal * factor,
                proteinGrams: item.proteinGrams * factor,
                carbsGrams: item.carbsGrams * factor,
                fatGrams: item.fatGrams * factor,
                confidence: item.confidence
            )
        }
    }

    private var selectedGrams: Double {
        switch portionMode {
        case .overall: return overallGrams
        case .detailed: return detailedItems.reduce(0) { $0 + $1.quantityGrams }
        }
    }

    private var selectedCalories: Double { selectedResult.totalCalories }
    private var selectedProtein: Double { selectedResult.totalProtein }
    private var selectedCarbs: Double { selectedResult.totalCarbs }
    private var selectedFat: Double { selectedResult.totalFat }

    private var overallFactor: Double {
        let base = max(1, Self.totalGrams(for: result.items))
        return overallGrams / base
    }

    private static func totalGrams(for items: [ScanResult.DetectedItem]) -> Double {
        items.reduce(0) { $0 + $1.quantityGrams }
    }

    private static func defaultOverallName(for result: ScanResult) -> String {
        guard !result.items.isEmpty else { return L("Posiłek") }
        if result.items.count == 1 { return result.items[0].name }
        return result.items.map(\.name).joined(separator: " + ")
    }

    private func aiCompletionUseCount(for items: [ScanResult.DetectedItem]) -> Int {
        let missingCount = items.filter(Self.needsNutrition).count
        guard missingCount > 0 else { return 0 }
        return portionMode == .overall ? 1 : missingCount
    }

    private func canConsumeAICompletion(count: Int) -> Bool {
        guard count > 0 else { return true }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap = entitlementsStore?.current.aiActionsPerWeek
        guard let cap, let usageMeter else { return true }
        if usageMeter.used(kind) + count <= cap { return true }
        Haptics.light()
        paywallCoordinator?.present(portionMode == .overall ? .mealAIRefreshQuota : .productNutritionQuota)
        return false
    }

    private func recordAICompletion(count: Int) {
        guard count > 0 else { return }
        let kind: UsageMeter.Kind = portionMode == .overall ? .mealAIRefresh : .productNutritionLookup
        let cap = entitlementsStore?.current.aiActionsPerWeek
        for _ in 0..<count {
            usageMeter?.record(kind, cap: cap)
        }
    }

    private static func needsNutrition(_ item: ScanResult.DetectedItem) -> Bool {
        item.caloriesKcal <= 0 || (item.proteinGrams <= 0 && item.carbsGrams <= 0 && item.fatGrams <= 0)
    }
}

private struct ScanResultFavoriteContext {
    let favoritesService: any FavoritesServing
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let userRemoteID: String
}

/// Wrapping row layout for the "Co widzimy" chips (mockup `flex-wrap`).
private struct ScanChipFlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .greatestFiniteMagnitude
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if cursorX > 0, cursorX + size.width > maxWidth {
                cursorX = 0
                cursorY += rowHeight + spacing
                rowHeight = 0
            }
            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, cursorX - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: cursorY + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var cursorX = bounds.minX
        var cursorY = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            if cursorX > bounds.minX, cursorX + size.width > bounds.maxX {
                cursorX = bounds.minX
                cursorY += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: cursorX, y: cursorY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height)
            )
            cursorX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
