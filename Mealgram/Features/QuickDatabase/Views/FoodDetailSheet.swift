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
        self._detailDrafts = State(initialValue: [
            QuickFoodIngredientDraft(
                name: food.localizedName,
                quantityGrams: initialGrams,
                caloriesKcalPer100g: food.caloriesKcalPer100g,
                proteinGramsPer100g: food.proteinGramsPer100g,
                carbsGramsPer100g: food.carbsGramsPer100g,
                fatGramsPer100g: food.fatGramsPer100g,
                fiberGramsPer100g: food.fiberGramsPer100g
            )
        ])
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
        let totalGrams = max(items.reduce(0) { $0 + $1.quantityGrams } * snapshot.portionMultiplier, 1)
        let title = snapshot.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? snapshot.notes ?? L("Ostatni posiłek")
            : items.prefix(2).map(\.name).joined(separator: " + ")
        let syntheticFood = Food(
            name: title.isEmpty ? L("Ostatni posiłek") : title,
            category: .homemade,
            caloriesKcalPer100g: items.reduce(0) { $0 + $1.caloriesKcal } * snapshot.portionMultiplier / totalGrams * 100,
            proteinGramsPer100g: items.reduce(0) { $0 + $1.proteinGrams } * snapshot.portionMultiplier / totalGrams * 100,
            carbsGramsPer100g: items.reduce(0) { $0 + $1.carbsGrams } * snapshot.portionMultiplier / totalGrams * 100,
            fatGramsPer100g: items.reduce(0) { $0 + $1.fatGrams } * snapshot.portionMultiplier / totalGrams * 100,
            defaultPortionGrams: totalGrams,
            verified: false
        )
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
            initialValue: items.map { item in
                QuickFoodIngredientDraft(
                    name: item.name,
                    quantityGrams: item.quantityGrams * snapshot.portionMultiplier,
                    caloriesKcalPer100g: item.quantityGrams > 0 ? item.caloriesKcal / item.quantityGrams * 100 : 0,
                    proteinGramsPer100g: item.quantityGrams > 0 ? item.proteinGrams / item.quantityGrams * 100 : 0,
                    carbsGramsPer100g: item.quantityGrams > 0 ? item.carbsGrams / item.quantityGrams * 100 : 0,
                    fatGramsPer100g: item.quantityGrams > 0 ? item.fatGrams / item.quantityGrams * 100 : 0,
                    fiberGramsPer100g: item.quantityGrams > 0 ? item.fiberGrams.map { $0 / item.quantityGrams * 100 } : nil
                )
            }
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                portionBackground
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Tokens.Space.lg) {
                        summaryHero
                        favoriteButton
                        modePicker
                        if portionMode == .overall {
                            portionCard
                        } else {
                            detailedIngredientsCard
                        }
                        macroCard
                        PrimaryButton(title: "Dodaj do dziennika", systemImage: "checkmark") {
                            commit()
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(Text(food.localizedName))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial, in: Circle())
                            .background(Circle().fill(Tokens.Palette.surface.opacity(0.72)))
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Close")
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

    private var portionBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.48))
                .frame(width: 350, height: 350)
                .blur(radius: 108)
                .offset(x: -160, y: -210)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.28))
                .frame(width: 310, height: 310)
                .blur(radius: 112)
                .offset(x: 160, y: -10)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.09))
                .frame(width: 250, height: 250)
                .blur(radius: 100)
                .offset(x: -80, y: 360)
        }
        .ignoresSafeArea()
    }

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

    // MARK: - Sections

    private var summaryHero: some View {
        HStack(spacing: Tokens.Space.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.white.opacity(0.18))
                    .frame(width: 74, height: 74)
                Image(systemName: "scalemass.fill")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(heroSubtitle ?? food.brand ?? food.restaurantName ?? "Mealgram")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                Text("\(Int(currentCalories.rounded())) kcal")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Text("\(Int(grams.rounded())) g · \(food.localizedName)")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.28, green: 0.62, blue: 0.49),
                            Color(red: 0.20, green: 0.44, blue: 0.52),
                            Color(red: 0.18, green: 0.25, blue: 0.36),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.12, green: 0.28, blue: 0.24).opacity(0.24), radius: 24, y: 14)
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

    private var portionCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Porcja")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Dopasuj wagę przed dodaniem")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Text("\(Int(grams.rounded())) g")
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Slider(value: $grams, in: 10...600, step: 5)
                .tint(Tokens.Palette.primary)
                .padding(.vertical, Tokens.Space.xs)

            HStack(spacing: Tokens.Space.sm) {
                ForEach([100, 150, 250, 400], id: \.self) { preset in
                    portionPresetButton(preset)
                }
            }

            HStack {
                Text("10 g")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                Spacer()
                Text("600 g")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }

    private func portionPresetButton(_ preset: Int) -> some View {
        Button {
            withAnimation(Tokens.Motion.quick) {
                grams = Double(preset)
            }
            Haptics.selection()
        } label: {
            Text("\(preset) g")
                .font(Tokens.Font.caption.weight(.bold))
                .foregroundStyle(Int(grams.rounded()) == preset ? .white : Tokens.Palette.ink)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Int(grams.rounded()) == preset ? Tokens.Palette.primary : Tokens.Palette.surfaceMuted)
                )
        }
        .buttonStyle(.pressable)
    }

    private var macroCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Makro")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("na wybraną porcję")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            HStack(spacing: Tokens.Space.sm) {
                macroPill(label: "Protein", grams: currentProtein, color: Tokens.Palette.primary)
                macroPill(label: "Węgle", grams: currentCarbs, color: Tokens.Palette.warning)
                macroPill(label: "Tłuszcz", grams: currentFat, color: Tokens.Palette.accent)
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
    }

    private var detailedIngredientsCard: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Składniki")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Edytuj gramaturę produktu przed zapisem")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                Text("\(Int(detailTotalGrams.rounded())) g")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Tokens.Palette.primarySoft))
            }

            ForEach($detailDrafts) { $draft in
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    HStack {
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
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(Tokens.Palette.error)
                            }
                            .buttonStyle(.pressable)
                        }
                    }
                    HStack {
                        Text("\(Int(draft.quantityGrams.rounded())) g")
                            .font(Tokens.Font.title3)
                            .foregroundStyle(Tokens.Palette.primary)
                            .contentTransition(.numericText())
                        Spacer()
                        Text("\(Int(draft.caloriesKcal.rounded())) kcal")
                            .font(Tokens.Font.footnote.weight(.bold))
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Slider(value: $draft.quantityGrams, in: 10...1200, step: 5)
                        .tint(Tokens.Palette.primary)
                    HStack(spacing: Tokens.Space.sm) {
                        macroPill(
                            label: "Protein",
                            grams: draft.proteinGrams,
                            color: Tokens.Palette.primary
                        )
                        macroPill(
                            label: "Węgle",
                            grams: draft.carbsGrams,
                            color: Tokens.Palette.warning
                        )
                        macroPill(
                            label: "Tłuszcz",
                            grams: draft.fatGrams,
                            color: Tokens.Palette.accent
                        )
                    }
                }
            }

            Button {
                detailDrafts.append(QuickFoodIngredientDraft(name: "", quantityGrams: 100))
                Haptics.selection()
            } label: {
                Label("Dodaj składnik", systemImage: "plus.circle.fill")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .buttonStyle(.pressable)
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.78))
        )
        .onChange(of: detailDrafts) { _, _ in syncOverallFromDetail() }
    }

    private func productAIButton(for draft: Binding<QuickFoodIngredientDraft>) -> some View {
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
        VStack(spacing: 5) {
            Text(String(format: "%.1f g", grams))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.11))
        )
    }

    // MARK: - Math

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
        let factor = max(completed.item.quantityGrams, 1) / 100
        detailDrafts[index].name = completed.item.name
        detailDrafts[index].quantityGrams = completed.item.quantityGrams
        detailDrafts[index].caloriesKcalPer100g = completed.item.caloriesKcal / factor
        detailDrafts[index].proteinGramsPer100g = completed.item.proteinGrams / factor
        detailDrafts[index].carbsGramsPer100g = completed.item.carbsGrams / factor
        detailDrafts[index].fatGramsPer100g = completed.item.fatGrams / factor
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

private struct FoodDetailFavoriteContext {
    let favoritesService: any FavoritesServing
    let entitlementsStore: EntitlementsStore
    let paywallCoordinator: PaywallCoordinator
    let userRemoteID: String
}

private struct QuickFoodIngredientDraft: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantityGrams: Double
    var caloriesKcalPer100g: Double
    var proteinGramsPer100g: Double
    var carbsGramsPer100g: Double
    var fatGramsPer100g: Double
    var fiberGramsPer100g: Double?

    init(
        name: String,
        quantityGrams: Double,
        caloriesKcalPer100g: Double = 0,
        proteinGramsPer100g: Double = 0,
        carbsGramsPer100g: Double = 0,
        fatGramsPer100g: Double = 0,
        fiberGramsPer100g: Double? = nil
    ) {
        self.name = name
        self.quantityGrams = quantityGrams
        self.caloriesKcalPer100g = caloriesKcalPer100g
        self.proteinGramsPer100g = proteinGramsPer100g
        self.carbsGramsPer100g = carbsGramsPer100g
        self.fatGramsPer100g = fatGramsPer100g
        self.fiberGramsPer100g = fiberGramsPer100g
    }

    var factor: Double { quantityGrams / 100 }
    var caloriesKcal: Double { caloriesKcalPer100g * factor }
    var proteinGrams: Double { proteinGramsPer100g * factor }
    var carbsGrams: Double { carbsGramsPer100g * factor }
    var fatGrams: Double { fatGramsPer100g * factor }
    var fiberGrams: Double? { fiberGramsPer100g.map { $0 * factor } }
}
