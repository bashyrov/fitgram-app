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
        ZStack(alignment: .top) {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    photoHero
                    contentPanel
                }
            }
            .ignoresSafeArea(edges: .top)
            closeButton
                .padding(.leading, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.sm)
            VStack {
                Spacer()
                footer
            }
        }
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

    /// Hero image at the top — lives inside the ScrollView so it
    /// parallax-scrolls naturally with the content below.
    private var photoHero: some View {
        preview
            .frame(height: 280)
            .frame(maxWidth: .infinity)
            .clipped()
    }

    /// Cards section with an opaque background + rounded top corners
    /// that overlap the photo by 28pt. Once the user scrolls, the
    /// cards visually float over the photo and the photo's bottom edge
    /// is fully hidden by the panel.
    private var contentPanel: some View {
        VStack(spacing: Tokens.Space.lg) {
            summaryCard
            favoriteButton
            modePicker
            if portionMode == .overall {
                overallCard
            } else {
                itemsCard
            }
            Color.clear.frame(height: 120)  // breathing room for the floating CTA
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            Tokens.Palette.background
                .clipShape(
                    .rect(
                        topLeadingRadius: 28,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 0,
                        topTrailingRadius: 28,
                        style: .continuous
                    )
                )
        )
        .offset(y: -28)
    }

    private var closeButton: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel(Text("Close"))
            Spacer()
        }
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

    private var preview: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: [Tokens.Palette.primarySoft, Tokens.Palette.surfaceMuted],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var summaryCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mealTypeLabel(for: result.suggestedMealType))
                            .font(Tokens.Font.subheadline)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text(String.localizedStringWithFormat(L("%lld kcal"), Int(selectedCalories.rounded())))
                            .font(Tokens.Font.counter)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    Spacer()
                    confidenceBadge
                }
                HStack(spacing: Tokens.Space.lg) {
                    macroPill(label: "Protein", grams: selectedProtein, color: Tokens.Palette.primary)
                    macroPill(label: "Carbs", grams: selectedCarbs, color: Tokens.Palette.warning)
                    macroPill(label: "Fat", grams: selectedFat, color: Tokens.Palette.accent)
                }
            }
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

    private var overallCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    HStack {
                        Text("Nazwa dania")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Spacer()
                        aiRefreshButton(text: overallName)
                    }
                    TextField("Risotto z krewetkami", text: $overallName)
                        .font(Tokens.Font.bodyEmphasized)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextInputFocused)
                        .submitLabel(.done)
                        .onSubmit { isTextInputFocused = false }
                }
                HStack {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(String.localizedStringWithFormat(L("%lld g"), Int(overallGrams.rounded())))
                            .font(Tokens.Font.title3)
                            .foregroundStyle(Tokens.Palette.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(String(format: "×%.2f", overallFactor))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Slider(value: $overallGrams, in: 10...1500, step: 5)
                    .tint(Tokens.Palette.primary)
                HStack {
                    Text("10 g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Spacer()
                    Text("1500 g")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
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

    private var itemsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text("Co widzimy")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    aiRefreshButton(text: result.items.map(\.name).joined(separator: ", "))
                    Text(String.localizedStringWithFormat(L("%lld elementów"), result.items.count))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                ForEach(result.items) { item in
                    itemRow(item)
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
                Button {
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
                } label: {
                    HStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Dodaj produkt")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, Tokens.Space.sm)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.Scan.addItem)
            }
        }
    }

    private func itemRow(_ item: ScanResult.DetectedItem) -> some View {
        let binding = Binding<Double>(
            get: { detailGrams[item.id] ?? item.quantityGrams },
            set: { detailGrams[item.id] = $0 }
        )
        let nameBinding = Binding<String>(
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
        let factor = item.quantityGrams > 0 ? binding.wrappedValue / item.quantityGrams : 1
        return HStack(spacing: Tokens.Space.md) {
            Circle()
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Tokens.Space.xs) {
                    TextField("Produkt", text: nameBinding)
                        .font(Tokens.Font.bodyEmphasized)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTextInputFocused)
                        .submitLabel(.done)
                        .onSubmit { isTextInputFocused = false }
                    Spacer(minLength: 0)
                    productAIButton(for: item)
                    if result.items.count > 1 {
                        Button {
                            result.items.removeAll(where: { $0.id == item.id })
                            detailGrams[item.id] = nil
                            Haptics.selection()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Tokens.Palette.error)
                        }
                        .buttonStyle(.pressable)
                    }
                }
                Slider(value: binding, in: 10...800, step: 5)
                    .tint(Tokens.Palette.primary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String.localizedStringWithFormat(L("%lld g"), Int(binding.wrappedValue.rounded())))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int((item.caloriesKcal * factor).rounded())))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
    }

    private func productAIButton(for item: ScanResult.DetectedItem) -> some View {
        Button {
            Task { await refreshProductNutrition(item) }
        } label: {
            HStack(spacing: 4) {
                if productLookupsInFlight.contains(item.id) {
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
        .frame(minWidth: 30, minHeight: 30)
        .foregroundStyle(Tokens.Palette.primary)
        .background(Circle().fill(Tokens.Palette.primarySoft))
        .buttonStyle(.pressable)
        .disabled(
            productLookupsInFlight.contains(item.id)
                || mealAnalyzer == nil
                || item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        )
        .accessibilityLabel(Text("Uzupełnij produkt AI"))
    }

    private var confidenceBadge: some View {
        let pct = Int(result.confidence * 100)
        return Text(String.localizedStringWithFormat(L("%lld%% confidence"), pct))
            .font(Tokens.Font.caption)
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, Tokens.Space.sm)
            .padding(.vertical, 4)
            .background(
                Capsule().fill(Tokens.Palette.primarySoft)
            )
    }

    private var footer: some View {
        VStack(spacing: Tokens.Space.sm) {
            PrimaryButton(
                title: isCompletingNutrition ? "Uzupełniam..." : "Dodaj do dziennika",
                systemImage: isCompletingNutrition ? "sparkles" : "checkmark",
                isEnabled: !isCompletingNutrition
            ) {
                Task { await saveSelectedResult() }
            }
            Button(action: onRetake) {
                Text("Take another")
                    .font(Tokens.Font.callout)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.bottom, Tokens.Space.xl)
        .padding(.top, Tokens.Space.md)
        .background(
            LinearGradient(
                colors: [Tokens.Palette.background.opacity(0), Tokens.Palette.background],
                startPoint: .top,
                endPoint: .center
            )
            .frame(maxHeight: .infinity)
            .allowsHitTesting(false)
        )
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
        Button {
            isTextInputFocused = false
            Task { await refreshFromAI(text: text) }
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
        .disabled(isAnalyzingText || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private var mealAIRefreshRemaining: Int? {
        usageMeter?.remaining(.mealAIRefresh, cap: entitlementsStore?.current.mealAIRefreshesPerDay)
    }

    private var productNutritionRemaining: Int? {
        usageMeter?.remaining(.productNutritionLookup, cap: entitlementsStore?.current.productNutritionLookupsPerDay)
    }

    private func refreshFromAI(text: String) async {
        guard let mealAnalyzer else { return }
        let cap = entitlementsStore?.current.mealAIRefreshesPerDay
        if usageMeter?.canUse(.mealAIRefresh, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.mealAIRefreshQuota)
            return
        }
        isAnalyzingText = true
        defer { isAnalyzingText = false }
        let analysis = await mealAnalyzer.analyze(text: text, mealType: result.suggestedMealType)
        usageMeter?.record(.mealAIRefresh, cap: cap)
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
        let cap = entitlementsStore?.current.productNutritionLookupsPerDay
        if usageMeter?.canUse(.productNutritionLookup, cap: cap) == false {
            Haptics.light()
            paywallCoordinator?.present(.productNutritionQuota)
            return
        }
        productLookupsInFlight.insert(item.id)
        defer { productLookupsInFlight.remove(item.id) }
        let draft = FoodItem(
            id: item.id,
            name: item.name,
            quantityGrams: currentGrams,
            caloriesKcal: 0,
            proteinGrams: 0,
            carbsGrams: 0,
            fatGrams: 0,
            confidence: item.confidence
        )
        let completed = await mealAnalyzer.complete(item: draft, mealType: result.suggestedMealType)
        usageMeter?.record(.productNutritionLookup, cap: cap)
        guard let index = result.items.firstIndex(where: { $0.id == item.id }) else { return }
        result.items[index] = ScanResult.DetectedItem(
            id: item.id,
            name: completed.item.name,
            quantityGrams: completed.item.quantityGrams,
            caloriesKcal: completed.item.caloriesKcal,
            proteinGrams: completed.item.proteinGrams,
            carbsGrams: completed.item.carbsGrams,
            fatGrams: completed.item.fatGrams,
            confidence: completed.item.confidence ?? item.confidence
        )
        detailGrams[item.id] = completed.item.quantityGrams
        Haptics.success()
    }

    // MARK: - Helpers

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(String.localizedStringWithFormat(L("%lld g"), Int(grams)))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func mealTypeLabel(for kind: MealType) -> LocalizedStringKey {
        switch kind {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
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

    private static func needsNutrition(_ item: ScanResult.DetectedItem) -> Bool {
        item.caloriesKcal <= 0 || item.proteinGrams <= 0 || item.carbsGrams <= 0 || item.fatGrams <= 0
    }
}

private struct ScanResultFavoriteContext {
    let favoritesService: any FavoritesServing
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let userRemoteID: String
}
