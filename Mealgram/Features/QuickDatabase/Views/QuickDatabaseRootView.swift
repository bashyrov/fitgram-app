import SwiftUI

/// Quick Database — browse + search the local Polish food catalogue. Tap
/// an item → portion sheet → save as a MealEntry with source=.quickDatabase.
struct QuickDatabaseRootView: View {
    @Bindable var state: QuickDatabaseState
    let mealSaver: any MealSaving
    let onDismiss: () -> Void

    @State private var pickedFood: Food?
    @State private var isAddingCustom = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: Tokens.Space.md) {
                    searchField
                    categoryStrip
                    list
                }
                .padding(.top, Tokens.Space.md)
            }
            .navigationTitle(Text("Szybka baza"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isAddingCustom = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("Dodaj własne danie"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij", action: onDismiss)
                }
            }
            .task { await state.refresh() }
            .sheet(item: $pickedFood) { food in
                FoodDetailSheet(
                    food: food,
                    onSave: { commit(food: food, item: $0, suggestedMealType: Self.suggestedMealType()) },
                    onDismiss: { pickedFood = nil }
                )
            }
            .sheet(isPresented: $isAddingCustom) {
                CustomFoodFormSheet(
                    onSave: { food in
                        Task {
                            await state.createCustomFood(food)
                            isAddingCustom = false
                        }
                    },
                    onDismiss: { isAddingCustom = false }
                )
            }
        }
    }

    // MARK: - Sections

    private var searchField: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Tokens.Palette.inkMuted)
            TextField(
                "Szukaj posiłku",
                text: Binding(
                    get: { state.query },
                    set: { value in Task { await state.applyQuery(value) } }
                )
            )
            .textInputAutocapitalization(.never)
            .submitLabel(.search)
            if !state.query.isEmpty {
                Button {
                    Task { await state.applyQuery("") }
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

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                chip(label: "Wszystkie", isSelected: state.selectedCategory == nil) {
                    Task { await state.selectCategory(nil) }
                }
                ForEach(state.availableCategories, id: \.self) { category in
                    chip(
                        label: category.localizedLabel,
                        isSelected: state.selectedCategory == category
                    ) {
                        Task { await state.selectCategory(category) }
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
        }
    }

    private func chip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Tokens.Font.footnote)
                .foregroundStyle(isSelected ? .white : Tokens.Palette.ink)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.sm)
                .background(
                    Capsule().fill(isSelected ? Tokens.Palette.primary : Tokens.Palette.surface)
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Tokens.Palette.primary : Tokens.Palette.separator,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(PressableButtonStyle())
    }

    @ViewBuilder
    private var list: some View {
        if state.foods.isEmpty {
            VStack(spacing: Tokens.Space.md) {
                Spacer()
                EmptyState(
                    symbol: "magnifyingglass",
                    title: "Nic nie znaleziono",
                    message: "Spróbuj innego hasła albo wyłącz filtr kategorii.",
                    action: nil
                )
                Spacer()
            }
        } else {
            ScrollView {
                LazyVStack(spacing: Tokens.Space.sm, pinnedViews: []) {
                    if state.shouldShowSuggestions {
                        suggestionsSection
                    }
                    ForEach(state.foods) { food in
                        foodRow(food)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxxl)
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        if !state.recentPicks.isEmpty {
            suggestionGroup(title: "Ostatnie", foods: state.recentPicks)
        }
        if !state.popularPicks.isEmpty {
            suggestionGroup(title: "Częste", foods: state.popularPicks)
        }
        Text("Wszystkie")
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Palette.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, Tokens.Space.md)
    }

    private func suggestionGroup(title: LocalizedStringKey, foods: [Food]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.sm) {
                    ForEach(foods) { food in
                        suggestionChip(food)
                    }
                }
            }
        }
    }

    private func suggestionChip(_ food: Food) -> some View {
        Button {
            pickedFood = food
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(food.name)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text("\(Int(food.caloriesKcalPer100g)) kcal / 100g")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(.vertical, Tokens.Space.sm)
            .padding(.horizontal, Tokens.Space.md)
            .frame(maxWidth: 220, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(Tokens.Palette.primarySoft)
            )
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func foodRow(_ food: Food) -> some View {
        Button {
            pickedFood = food
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primarySoft)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon(for: food.category))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Tokens.Palette.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle(for: food))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(Int(food.caloriesKcalPer100g)) kcal/100g")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
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
    }

    private func subtitle(for food: Food) -> String {
        if let restaurant = food.restaurantName, !restaurant.isEmpty { return restaurant }
        if let brand = food.brand, !brand.isEmpty { return brand }
        return food.category.localizedLabel
    }

    private static let categoryIcons: [FoodCategory: String] = [
        .homemade: "house.fill",
        .fastFood: "takeoutbag.and.cup.and.straw.fill",
        .restaurant: "fork.knife",
        .bakery: "birthday.cake.fill",
        .beverage: "cup.and.saucer.fill",
        .dairy: "drop.fill",
        .meat: "flame.fill",
        .seafood: "fish.fill",
        .produce: "leaf.fill",
        .grain: "bowl.fill",
        .sweets: "birthday.cake.fill",
        .packaged: "shippingbox.fill",
        .snack: "popcorn.fill",
        .general: "circle.fill",
    ]

    private func icon(for category: FoodCategory) -> String {
        Self.categoryIcons[category] ?? "circle.fill"
    }

    // MARK: - Save

    private func commit(food: Food, item: FoodItem, suggestedMealType: MealType) {
        let entry = MealEntry(
            mealType: suggestedMealType,
            source: .quickDatabase,
            items: [item]
        )
        try? mealSaver.save(meal: entry)
        state.recordPick(food)
        onDismiss()
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
