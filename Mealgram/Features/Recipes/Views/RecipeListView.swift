import SwiftUI

/// Browses saved recipes; tap a row to view + cook, swipe to delete,
/// trailing "+" raises the form sheet.
struct RecipeListView: View {
    @Bindable var state: RecipeListState
    let repository: RecipeRepository
    let mealSaver: any MealSaving
    let onDismiss: () -> Void
    var estimator: RecipeNutritionEstimator?

    @State private var formMode: FormPresentation?
    @State private var detailRecipe: Recipe?
    @State private var isImportPresented = false

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
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: Tokens.Space.md) {
                    searchField
                    list
                }
                .padding(.top, Tokens.Space.md)
            }
            .navigationTitle(Text("Moje przepisy"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Tokens.Space.sm) {
                        Button {
                            state.favoritesOnly.toggle()
                            Haptics.selection()
                        } label: {
                            Image(systemName: state.favoritesOnly ? "heart.fill" : "heart")
                                .foregroundStyle(
                                    state.favoritesOnly ? Tokens.Palette.warning : Tokens.Palette.inkMuted
                                )
                        }
                        .accessibilityLabel(Text("Filtr ulubionych"))
                        Menu {
                            Picker("Sortuj", selection: $state.sort) {
                                ForEach(RecipeListState.Sort.allCases, id: \.self) { sort in
                                    Text(sort.label).tag(sort)
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        .accessibilityLabel(Text("Sortuj"))
                        Menu {
                            Button {
                                formMode = .adding
                            } label: {
                                Label("Wpisz ręcznie", systemImage: "square.and.pencil")
                            }
                            Button {
                                isImportPresented = true
                            } label: {
                                Label("Importuj z URL", systemImage: "link")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("Dodaj przepis"))
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Zamknij", action: onDismiss)
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
                    onCook: { servings in cook(recipe, servings: servings) },
                    onEdit: {
                        detailRecipe = nil
                        formMode = .editing(recipe)
                    },
                    onDismiss: { detailRecipe = nil }
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField("Szukaj przepisu", text: $state.query)
                .textInputAutocapitalization(.never)
            if !state.query.isEmpty {
                Button {
                    state.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
    }

    @ViewBuilder
    private var list: some View {
        if state.filtered.isEmpty {
            VStack(spacing: Tokens.Space.lg) {
                Spacer()
                EmptyState(
                    symbol: "book.closed.fill",
                    title: state.recipes.isEmpty ? "Brak przepisów" : "Nic nie znaleziono",
                    message: state.recipes.isEmpty
                        ? "Zapisz pierwszy przepis, żeby szybko dodać go do dziennika kolejnym razem."
                        : "Spróbuj innego hasła.",
                    action: state.recipes.isEmpty
                        ? .init(title: "Dodaj przepis", perform: { formMode = .adding })
                        : nil
                )
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Tokens.Space.sm) {
                    ForEach(state.filtered) { recipe in
                        row(recipe)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    // swiftlint:disable function_body_length
    private func row(_ recipe: Recipe) -> some View {
        Button {
            detailRecipe = recipe
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 40, height: 40)
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Tokens.Palette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipe.title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle(for: recipe))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if recipe.cookCount > 0 {
                    Text("× \(recipe.cookCount)")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                if recipe.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                }
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .stroke(Tokens.Palette.separator, lineWidth: 1)
            )
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
                Label("Edytuj", systemImage: "pencil")
            }
            Button(role: .destructive) {
                delete(recipe)
            } label: {
                Label("Usuń", systemImage: "trash")
            }
        }
    }

    // swiftlint:enable function_body_length

    private func toggleFavorite(_ recipe: Recipe) {
        recipe.isFavorite.toggle()
        try? repository.save(recipe)
        Haptics.light()
    }

    private func subtitle(for recipe: Recipe) -> String {
        var parts: [String] = []
        parts.append("\(recipe.servings) porcje")
        if let kcal = recipe.caloriesPerServing, kcal > 0 {
            parts.append("\(Int(kcal)) kcal / porcję")
        }
        if !recipe.ingredients.isEmpty {
            parts.append("\(recipe.ingredients.count) składników")
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Actions

    private func handle(draft: RecipeDraft, mode: FormPresentation) {
        switch mode {
        case .adding:
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
            try? repository.create(recipe)
        case .editing(let recipe):
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
            try? repository.save(recipe)
        }
        Task { await state.refresh() }
    }

    private func cook(_ recipe: Recipe, servings: Double) {
        let entry = repository.cook(recipe, servings: servings)
        try? mealSaver.save(meal: entry)
        try? repository.save(recipe)
        detailRecipe = nil
        onDismiss()
    }

    private func delete(_ recipe: Recipe) {
        try? repository.delete(recipe)
        Task { await state.refresh() }
    }

    private func presentation(for mode: FormPresentation) -> RecipeFormSheet.Mode {
        switch mode {
        case .adding: return .adding
        case .editing(let recipe): return .editing(recipe)
        }
    }
}
