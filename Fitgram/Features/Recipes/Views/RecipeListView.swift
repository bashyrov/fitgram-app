import SwiftUI

// swiftlint:disable file_length

/// Browses saved recipes; tap a row to view + cook, swipe to delete,
/// trailing "+" raises the form sheet.
struct RecipeListView: View {
    // Owned (not @Bindable) so parent re-renders can't swap in a fresh state.
    @State var state: RecipeListState
    let repository: RecipeRepository
    let mealSaver: any MealSaving
    let onDismiss: () -> Void
    var estimator: RecipeNutritionEstimator?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var mealAnalyzer: MealTextAnalysisService?
    var usageMeter: UsageMeter?

    @State private var formMode: FormPresentation?
    @State private var detailRecipe: Recipe?
    @State private var isImportPresented = false
    @State private var saveError: String?

    private let importer = RecipeURLImporter()

    private enum FormPresentation: Identifiable {
        case adding
        case editing(Recipe)

        var id: String {
            switch self {
            case .adding: return "adding"
            case .editing(let recipe): return "editing-\(recipe.id.uuidString)"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(text: L("My recipes"), sub: countLine)
                    if state.filtered.count != state.recipes.count {
                        Button {
                            state.query = ""
                            state.favoritesOnly = false
                        } label: {
                            Text("Wyczyść filtry")
                                .font(Tokens.Font.manrope(12, weight: 800))
                                .foregroundStyle(Tokens.Palette.ink)
                                .underline()
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.top, 6)
                    }
                    searchBar
                        .padding(.top, 12)
                    list
                        .padding(.top, 12)
                    addRecipeCard
                        .padding(.top, 12)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("My recipes"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            presentAddRecipe()
                        } label: {
                            Label("Wpisz ręcznie", systemImage: "square.and.pencil")
                        }
                        Button {
                            presentImportRecipe()
                        } label: {
                            Label("Import from URL", systemImage: "link")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                    }
                    .accessibilityLabel(Text("Add recipe"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
            }
            .task { await state.refresh() }
            .sheet(item: $formMode) { mode in
                RecipeFormSheet(
                    mode: presentation(for: mode),
                    onCommit: { draft in handle(draft: draft, mode: mode) },
                    onDismiss: { formMode = nil },
                    estimator: estimator
                )
            }
            .sheet(isPresented: $isImportPresented) {
                RecipeImportSheet(
                    importer: importer,
                    onImported: { draft in
                        isImportPresented = false
                        handle(draft: draft, mode: .adding)
                        Task { await state.refresh() }
                    },
                    onDismiss: { isImportPresented = false }
                )
            }
            .sheet(item: $detailRecipe) { recipe in
                RecipeDetailView(
                    recipe: recipe,
                    onCook: { items in cook(recipe, items: items) },
                    onEdit: {
                        detailRecipe = nil
                        formMode = .editing(recipe)
                    },
                    onRate: { newValue in rate(recipe, value: newValue) },
                    onDismiss: { detailRecipe = nil },
                    similarRecipes: visibleSimilarRecipes(for: recipe),
                    onSelectSimilar: { peer in
                        guard canAccessRecipe(peer) else {
                            Haptics.light()
                            paywallCoordinator?.present(.recipesCap)
                            return
                        }
                        detailRecipe = peer
                    },
                    mealAnalyzer: mealAnalyzer,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    usageMeter: usageMeter
                )
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
extension RecipeListView {
    private var countLine: String {
        String.localizedStringWithFormat(L("%lld z %lld przepisów"), state.filtered.count, state.recipes.count)
    }

    private var lockedCount: Int {
        state.filtered.filter { isRecipeLocked($0) }.count
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            RecipeSearchField(query: $state.query)
            Button {
                state.favoritesOnly.toggle()
                Haptics.selection()
            } label: {
                Image(systemName: state.favoritesOnly ? "heart.fill" : "heart")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(state.favoritesOnly ? Tokens.Mono.onHero : Tokens.Palette.ink)
                    .frame(width: 46, height: 46)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(state.favoritesOnly ? Tokens.Mono.hero : Color.clear)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(state.favoritesOnly ? Color.clear : Tokens.Mono.line2, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Filtr ulubionych"))
            .accessibilityAddTraits(state.favoritesOnly ? .isSelected : [])
            Menu {
                Picker("Sort", selection: $state.sort) {
                    ForEach(RecipeListState.Sort.allCases, id: \.self) { sort in
                        Text(sort.label).tag(sort)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(state.sort.label)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .heavy))
                }
                .font(Tokens.Font.manrope(13, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Tokens.Mono.line2, lineWidth: 1)
                )
            }
            .accessibilityLabel(Text("Sort"))
        }
    }

    @ViewBuilder
    private var list: some View {
        if state.filtered.isEmpty {
            VStack(spacing: 8) {
                MonoIconBox(systemName: "book.closed", style: .track, size: 44)
                Text(state.recipes.isEmpty ? "No recipes" : "Nothing found")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    state.recipes.isEmpty
                        ? "Zapisz pierwszy przepis, żeby szybko dodać go do dziennika kolejnym razem."
                        : "Spróbuj innego hasła."
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 18)
        } else {
            VStack(spacing: 14) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(state.filtered.enumerated()), id: \.element.id) { index, recipe in
                        if index > 0 {
                            MonoRowDivider(inset: 16)
                        }
                        if isRecipeLocked(recipe) {
                            lockedRow(recipe)
                        } else {
                            row(recipe)
                        }
                    }
                }
                .monoRowsCard()
                if lockedCount > 0 {
                    hiddenRecipesCard
                }
            }
        }
    }

    private var hiddenRecipesCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "lock.fill", style: .dark, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(String.localizedStringWithFormat(L("+%lld hidden recipes"), lockedCount))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Premium pokazuje całą Twoją kolekcję bez limitu.")
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            MonoButton(title: "Premium", kind: .accent, icon: "star.fill", height: 40, fullWidth: false) {
                Haptics.light()
                paywallCoordinator?.present(.recipesCap)
            }
        }
        .monoCard(padding: 16)
    }

    private var addRecipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: L("Add recipe"))
            HStack(spacing: 8) {
                MonoButton(title: L("Wpisz ręcznie"), kind: .outline, icon: "pencil", height: 44) {
                    presentAddRecipe()
                }
                MonoButton(title: L("Import from URL"), kind: .outline, icon: "link", height: 44) {
                    presentImportRecipe()
                }
            }
        }
        .monoCard(padding: 16)
    }

    private func row(_ recipe: Recipe) -> some View {
        Button {
            detailRecipe = recipe
        } label: {
            RecipeListRowLabel(recipe: recipe)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                toggleFavorite(recipe)
            } label: {
                Label(
                    recipe.isFavorite ? "Usuń z ulubionych" : "Dodaj do ulubionych",
                    systemImage: recipe.isFavorite ? "heart.slash" : "heart.fill"
                )
            }
            Button {
                detailRecipe = nil
                formMode = .editing(recipe)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                duplicateRecipe(recipe)
            } label: {
                Label("Duplikuj", systemImage: "doc.on.doc")
            }
            Button(role: .destructive) {
                delete(recipe)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func lockedRow(_ recipe: Recipe) -> some View {
        Button {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
        } label: {
            LockedRecipeRowLabel(title: recipe.title)
        }
        .buttonStyle(.plain)
    }

    private func duplicateRecipe(_ recipe: Recipe) {
        guard canPersistNewRecipe(), canPersistRecipeAction(recipe) else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        do {
            try repository.duplicate(recipe)
            Haptics.light()
            Task { await state.refresh() }
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    private func rate(_ recipe: Recipe, value: Double?) {
        guard canPersistRecipeAction(recipe) else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        let previous = recipe.rating
        recipe.rating = value
        do {
            try repository.save(recipe)
            Task { await state.refresh() }
        } catch {
            recipe.rating = previous
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    private func toggleFavorite(_ recipe: Recipe) {
        guard canPersistRecipeAction(recipe) else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        let previous = recipe.isFavorite
        recipe.isFavorite.toggle()
        do {
            try repository.save(recipe)
            Haptics.light()
        } catch {
            recipe.isFavorite = previous
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }
}

// MARK: - Actions
extension RecipeListView {
    private func handle(draft: RecipeDraft, mode: FormPresentation) {
        let saved: Bool
        switch mode {
        case .adding:
            saved = createRecipe(from: draft)
        case .editing(let recipe):
            saved = updateRecipe(recipe, from: draft)
        }
        if saved {
            Task { await state.refresh() }
        }
    }

    private func createRecipe(from draft: RecipeDraft) -> Bool {
        guard canPersistNewRecipe() else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return false
        }
        let recipe = Recipe(
            title: draft.title,
            summary: draft.summary,
            servings: draft.servings,
            instructions: draft.instructions,
            ingredients: draft.ingredients.map { RecipeIngredient(name: $0) }
        )
        recipe.caloriesPerServing = draft.caloriesPerServing
        recipe.proteinPerServing = draft.proteinPerServing
        recipe.carbsPerServing = draft.carbsPerServing
        recipe.fatPerServing = draft.fatPerServing
        recipe.prepMinutes = draft.prepMinutes
        recipe.cookMinutes = draft.cookMinutes
        do {
            try repository.create(recipe)
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
            return false
        }
        return true
    }

    private func updateRecipe(_ recipe: Recipe, from draft: RecipeDraft) -> Bool {
        guard canPersistRecipeAction(recipe) else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return false
        }
        let previous = RecipeRollbackSnapshot(recipe)
        recipe.title = draft.title
        recipe.summary = draft.summary
        recipe.servings = draft.servings
        recipe.instructions = draft.instructions
        recipe.ingredients.forEach { ingredient in
            if !draft.ingredients.contains(ingredient.name) {
                // remove gone-from-form ingredient
                let context = recipe.modelContext
                context?.delete(ingredient)
            }
        }
        let existing = Set(recipe.ingredients.map(\.name))
        for newName in draft.ingredients where !existing.contains(newName) {
            recipe.ingredients.append(RecipeIngredient(name: newName))
        }
        recipe.caloriesPerServing = draft.caloriesPerServing
        recipe.proteinPerServing = draft.proteinPerServing
        recipe.carbsPerServing = draft.carbsPerServing
        recipe.fatPerServing = draft.fatPerServing
        do {
            try repository.save(recipe)
        } catch {
            previous.restore(recipe)
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
            return false
        }
        return true
    }

    private var canAddRecipe: Bool {
        guard let cap = entitlementsStore?.current.savedRecipesCap else { return true }
        return state.recipes.count < cap
    }

    private var unlockedRecipeIDs: Set<UUID>? {
        guard let cap = entitlementsStore?.current.savedRecipesCap else { return nil }
        return RecipeCapPolicy.unlockedIDs(in: state.recipes, cap: cap)
    }

    private func isRecipeLocked(_ recipe: Recipe) -> Bool {
        !canAccessRecipe(recipe)
    }

    private func canAccessRecipe(_ recipe: Recipe) -> Bool {
        guard let unlockedRecipeIDs else { return true }
        return unlockedRecipeIDs.contains(recipe.id)
    }

    private func canPersistNewRecipe() -> Bool {
        guard let cap = entitlementsStore?.current.savedRecipesCap else { return true }
        let currentRecipes = (try? repository.all()) ?? state.recipes
        return currentRecipes.count < cap
    }

    private func canPersistRecipeAction(_ recipe: Recipe) -> Bool {
        guard let cap = entitlementsStore?.current.savedRecipesCap else { return true }
        let currentRecipes = (try? repository.all()) ?? state.recipes
        return RecipeCapPolicy.unlockedIDs(in: currentRecipes, cap: cap).contains(recipe.id)
    }

    private func visibleSimilarRecipes(for recipe: Recipe) -> [Recipe] {
        SimilarRecipesEngine.similar(to: recipe, in: state.recipes)
            .filter(canAccessRecipe)
    }

    private func presentAddRecipe() {
        guard canAddRecipe else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        formMode = .adding
    }

    private func presentImportRecipe() {
        guard canAddRecipe else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        isImportPresented = true
    }

    private func cook(_ recipe: Recipe, items: [FoodItem]) {
        guard canPersistRecipeAction(recipe) else {
            Haptics.light()
            paywallCoordinator?.present(.recipesCap)
            return
        }
        let entry = MealEntry(
            mealType: RecipeRepository.suggestedMealType(forHour: Calendar.current.component(.hour, from: Date())),
            source: .recipe,
            portionMultiplier: 1,
            items: items
        )
        let previousCookCount = recipe.cookCount
        let previousUpdatedAt = recipe.updatedAt
        recipe.cookCount += 1
        recipe.updatedAt = Date()
        do {
            try mealSaver.save(meal: entry)
            try repository.save(recipe)
            detailRecipe = nil
            onDismiss()
        } catch {
            recipe.cookCount = previousCookCount
            recipe.updatedAt = previousUpdatedAt
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    private func delete(_ recipe: Recipe) {
        do {
            try repository.delete(recipe)
            Task { await state.refresh() }
        } catch {
            Haptics.warning()
            saveError = L("Couldn't save. Try again.")
        }
    }

    private func presentation(for mode: FormPresentation) -> RecipeFormSheet.Mode {
        switch mode {
        case .adding: return .adding
        case .editing(let recipe): return .editing(recipe)
        }
    }
}
