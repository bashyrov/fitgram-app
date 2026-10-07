import SwiftUI

/// Quick Database — browse + search the local Polish food catalogue. Tap
/// an item → portion sheet → save as a MealEntry with source=.quickDatabase.
struct QuickDatabaseRootView: View {
    @Bindable var state: QuickDatabaseState
    let mealSaver: any MealSaving
    let onDismiss: () -> Void
    var favoritesService: (any FavoritesServing)?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var userRemoteID: String?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    @State private var pickedFood: Food?
    @State private var isResetConfirmed = false
    @State private var saveError: String?
    @State private var isCustomFoodPresented = false
    @State private var isLabelScannerPresented = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                    .padding(.top, 6)
                categoryStrip
                    .padding(.top, 10)
                list
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Baza dań"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
                if state.shouldShowSuggestions {
                    ToolbarItem(placement: .topBarTrailing) {
                        optionsMenu
                    }
                }
            }
            .task { await state.refresh() }
            .sheet(item: $pickedFood) { food in
                foodDetailSheet(food)
            }
            .sheet(isPresented: $isCustomFoodPresented) {
                customFoodSheet
            }
            .sheet(isPresented: $isLabelScannerPresented) {
                labelScannerSheet
            }
            .confirmationDialog(
                "Zresetować ostatnie i częste?",
                isPresented: $isResetConfirmed,
                titleVisibility: .visible
            ) {
                Button("Resetuj", role: .destructive) {
                    Task { await state.resetPickHistory() }
                }
                Button("Anuluj", role: .cancel) {}
            } message: {
                Text("Ostatnie i częste dania wrócą do domyślnego widoku.")
            }
            .alert(
                "Nie udało się zapisać posiłku",
                isPresented: Binding(
                    get: { saveError != nil },
                    set: { if !$0 { saveError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: {
                Text(saveError ?? "Spróbuj ponownie.")
            }
        }
    }
}

// MARK: - Sections
extension QuickDatabaseRootView {
    private func foodDetailSheet(_ food: Food) -> some View {
        FoodDetailSheet(
            food: food,
            onSave: { commit(food: food, items: $0, suggestedMealType: Self.suggestedMealType()) },
            onDismiss: { pickedFood = nil },
            favoritesService: favoritesService,
            entitlementsStore: entitlementsStore,
            paywallCoordinator: paywallCoordinator,
            userRemoteID: userRemoteID,
            mealAnalyzer: mealAnalyzer,
            usageMeter: usageMeter
        )
    }

    private var customFoodSheet: some View {
        CustomFoodFormSheet(
            onSave: { food in
                isCustomFoodPresented = false
                Task { await state.createCustomFood(food) }
            },
            onDismiss: { isCustomFoodPresented = false }
        )
    }

    private var labelScannerSheet: some View {
        LabelScannerSheet(
            scanner: FoodLabelScanner(),
            onSave: { food in
                isLabelScannerPresented = false
                Task { await state.createCustomFood(food) }
            },
            onDismiss: { isLabelScannerPresented = false }
        )
    }

    /// `nav(..., 'gear', 'icon')`: round outline icon button holding the reset menu.
    private var optionsMenu: some View {
        Menu {
            Button(role: .destructive) {
                isResetConfirmed = true
            } label: {
                Label("Resetuj ostatnie i częste", systemImage: "arrow.counterclockwise")
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .accessibilityLabel(Text("Więcej opcji"))
    }

    /// 50 pt search bar: card fill, line2 border, radius 16.
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Tokens.Mono.muted)
            TextField(
                "Szukaj dania",
                text: Binding(
                    get: { state.query },
                    set: { value in Task { await state.applyQuery(value) } }
                )
            )
            .font(Tokens.Font.manrope(15, weight: 600))
            .foregroundStyle(Tokens.Palette.ink)
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !state.query.isEmpty {
                Button {
                    Task { await state.applyQuery("") }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Tokens.Mono.line2, lineWidth: 1)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    /// `chips([...], 0)`: Wszystko · categories · Tylko moje.
    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                MonoChip(title: L("Wszystko"), isSelected: state.selectedCategory == nil) {
                    Task { await state.selectCategory(nil) }
                }
                ForEach(state.availableCategories, id: \.self) { category in
                    MonoChip(
                        title: category.localizedLabel,
                        isSelected: state.selectedCategory == category
                    ) {
                        Task { await state.selectCategory(category) }
                    }
                }
                if state.hasCustomFoods {
                    MonoChip(title: L("Tylko moje"), isSelected: state.customOnly) {
                        Task { await state.toggleCustomOnly() }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if state.shouldShowSuggestions && !state.foods.isEmpty {
                    suggestionsSection
                }
                allSection
                addOwnCard
                    .padding(.top, 12)
                longPressCard
                    .padding(.top, 14)
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, 34)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if !state.recentPicks.isEmpty {
            suggestionGroup(title: L("Ostatnie"), foods: state.recentPicks)
        }
        if !state.popularPicks.isEmpty {
            suggestionGroup(title: L("Częste"), foods: state.popularPicks)
        }
    }

    /// `carousel(title, items)`: section header + 140 pt cards (radius 18).
    private func suggestionGroup(title: String, foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoSectionHeader(title: title)
                .padding(.horizontal, 6)
                .padding(.top, 20 - Tokens.Space.lg)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(foods) { food in
                        suggestionChip(food)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    private func suggestionChip(_ food: Food) -> some View {
        Button {
            pickedFood = food
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(food.localizedName)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(Int(food.caloriesKcalPer100g)) kcal/100g")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            .padding(12)
            .frame(width: 140, alignment: .topLeading)
            .monoSurface(radius: 18)
        }
        .buttonStyle(PressableButtonStyle())
    }

    /// `sec('', 'Wszystko', count)` + one rows card (divider inset 16).
    @ViewBuilder
    private var allSection: some View {
        MonoSectionHeader(title: L("Wszystko")) {
            if !state.foods.isEmpty {
                MonoLabel(text: "\(state.foods.count)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 22 - Tokens.Space.lg)
        .padding(.bottom, 12)
        if state.isLoading && state.foods.isEmpty {
            VStack(spacing: Tokens.Space.sm) {
                ForEach(0..<8, id: \.self) { _ in
                    LoadingShimmer(cornerRadius: Tokens.Radius.md)
                        .frame(height: 64)
                }
            }
        } else if state.foods.isEmpty {
            EmptyState(
                symbol: "magnifyingglass",
                title: "Nic nie znaleziono",
                message: "Spróbuj innego zapytania albo wyczyść filtr kategorii.",
                action: nil
            )
            .padding(.vertical, Tokens.Space.lg)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(state.foods.enumerated()), id: \.element.id) { index, food in
                    if index > 0 {
                        MonoRowDivider(inset: 16)
                    }
                    foodRow(food)
                }
            }
            .monoRowsCard()
        }
    }

    /// `row(None, name, 'X kcal / 100 g', dark + button)`.
    private func foodRow(_ food: Food) -> some View {
        Button {
            pickedFood = food
        } label: {
            MonoRow(title: food.localizedName, sub: subtitle(for: food)) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Tokens.Mono.hi)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Tokens.Mono.hero))
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if food.defaultPortionGrams != nil {
                Button {
                    quickLog(food)
                } label: {
                    Label("Dodaj domyślną porcję", systemImage: "bolt.fill")
                }
            }
            Button {
                pickedFood = food
            } label: {
                Label("Wybierz wielkość…", systemImage: "ruler")
            }
        }
    }

    /// "Nie ma Twojego dania?" — add a custom food or scan a nutrition label.
    private var addOwnCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MonoIconBox(systemName: "plus", style: .track, size: 36)
                VStack(alignment: .leading, spacing: 0) {
                    Text(
                        TL(
                            pl: "Nie ma Twojego dania?", en: "Can't find your dish?", uk: "Немає твоєї страви?",
                            ru: "Нет твоего блюда?", es: "¿No encuentras tu plato?"
                        )
                    )
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        TL(
                            pl: "Dodaj własne albo zeskanuj etykietę.", en: "Add your own or scan a label.",
                            uk: "Додай власну або скануй етикетку.", ru: "Добавь своё или отсканируй этикетку.",
                            es: "Añade el tuyo o escanea una etiqueta."
                        )
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                MonoButton(title: L("Dodaj do bazy"), kind: .outline, icon: "plus", height: 44) {
                    isCustomFoodPresented = true
                }
                MonoButton(
                    title: TL(
                        pl: "Skanuj etykietę", en: "Scan label", uk: "Сканувати етикетку",
                        ru: "Сканировать этикетку", es: "Escanear etiqueta"
                    ),
                    kind: .dark,
                    icon: "camera",
                    height: 44
                ) {
                    isLabelScannerPresented = true
                }
            }
        }
        .monoCard(padding: 16)
    }

    /// "Długie przytrzymanie" hint describing the row context menu.
    private var longPressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(
                text: TL(
                    pl: "Długie przytrzymanie", en: "Long press", uk: "Довге натискання",
                    ru: "Долгое нажатие", es: "Mantén pulsado"
                )
            )
            VStack(alignment: .leading, spacing: 6) {
                Label("Dodaj domyślną porcję", systemImage: "bolt")
                Label("Wybierz wielkość…", systemImage: "ruler")
            }
            .font(Tokens.Font.manrope(14, weight: 700))
            .foregroundStyle(Tokens.Palette.ink)
            .labelStyle(QuickDatabaseHintLabelStyle())
        }
        .monoCard(padding: 16)
    }

    /// One-tap commit using the food's default portion. Skips the
    /// FoodDetailSheet entirely — useful when the user picks the same
    /// staple every day.
    private func quickLog(_ food: Food) {
        guard let portion = food.defaultPortionGrams, portion > 0 else { return }
        let scale = portion / 100
        let item = FoodItem(
            name: food.localizedName,
            quantityGrams: portion,
            caloriesKcal: food.caloriesKcalPer100g * scale,
            proteinGrams: food.proteinGramsPer100g * scale,
            carbsGrams: food.carbsGramsPer100g * scale,
            fatGrams: food.fatGramsPer100g * scale
        )
        commit(food: food, items: [item], suggestedMealType: Self.suggestedMealType())
    }

    /// "X kcal / 100 g · brand or category" (+ " · moje" for user-authored rows).
    private func subtitle(for food: Food) -> String {
        var parts = ["\(Int(food.caloriesKcalPer100g)) kcal / 100 g"]
        if let restaurant = food.restaurantName, !restaurant.isEmpty {
            parts.append(restaurant)
        } else if let brand = food.brand, !brand.isEmpty {
            parts.append(brand)
        } else {
            parts.append(food.category.localizedLabel)
        }
        if !food.verified {
            parts.append(TL(pl: "moje", en: "mine", uk: "моє", ru: "моё", es: "mío"))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Save
extension QuickDatabaseRootView {
    private func commit(food: Food, items: [FoodItem], suggestedMealType: MealType) {
        let entry = MealEntry(
            mealType: suggestedMealType,
            source: .quickDatabase,
            items: items
        )
        do {
            try mealSaver.save(meal: entry)
            state.recordPick(food)
            onDismiss()
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    static func suggestedMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}

/// Icon + title line used in the "Długie przytrzymanie" hint card.
private struct QuickDatabaseHintLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 16)
            configuration.title
        }
    }
}
