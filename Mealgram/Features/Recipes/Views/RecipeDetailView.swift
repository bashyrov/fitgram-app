import SwiftUI
import UIKit

// swiftlint:disable type_body_length

/// Read-only view of a saved recipe with a "cook" CTA that scales the per-
/// serving nutrition and pipes it through `MealSaving`.
struct RecipeDetailView: View {
    let recipe: Recipe
    let onCook: ([FoodItem]) -> Void
    let onEdit: () -> Void
    let onRate: (Double?) -> Void
    let onDismiss: () -> Void
    var similarRecipes: [Recipe] = []
    var onSelectSimilar: ((Recipe) -> Void)?
    var mealAnalyzer: MealTextAnalysisService?
    var entitlementsStore: EntitlementsStore?
    var paywallCoordinator: PaywallCoordinator?
    var usageMeter: UsageMeter?

    @State private var servings: Double = 1
    @State private var checkedIngredients: Set<UUID> = []
    @State private var didCopyIngredients = false
    @State private var activeModIntent: RecipeModificationEngine.Intent?
    @State private var isPortionSheetPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                        header
                        if let summary = recipe.summary, !summary.isEmpty {
                            summaryCard(summary)
                        }
                        nutritionCard
                        ratingCard
                        servingsCard
                        if !recipe.ingredients.isEmpty {
                            ingredientsCard
                        }
                        if !recipe.instructions.isEmpty {
                            instructionsCard
                        }
                        if let minutes = recipe.cookMinutes, minutes > 0 {
                            CookTimerCard(cookMinutes: minutes)
                        }
                        if !similarRecipes.isEmpty, let onSelectSimilar {
                            similarCard(onSelectSimilar)
                        }
                        PrimaryButton(title: "Ugotuj i dodaj do dziennika", systemImage: "checkmark") {
                            isPortionSheetPresented = true
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text(recipe.title))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Tokens.Space.sm) {
                        if !recipe.ingredients.isEmpty {
                            ShareLink(
                                item: shoppingListText,
                                subject: Text(String.localizedStringWithFormat(L("Shopping list — %@"), recipe.title)),
                                preview: SharePreview(
                                    String.localizedStringWithFormat(L("Shopping list — %@"), recipe.title),
                                    icon: Image(systemName: "cart")
                                )
                            ) {
                                Image(systemName: "cart")
                            }
                            .accessibilityLabel(Text("Lista zakupów"))
                        }
                        if !recipe.ingredients.isEmpty {
                            Menu {
                                ForEach(RecipeModificationEngine.Intent.allCases, id: \.self) { intent in
                                    Button {
                                        activeModIntent = intent
                                    } label: {
                                        Label(intent.label, systemImage: intent.symbol)
                                    }
                                }
                            } label: {
                                Image(systemName: "wand.and.stars")
                            }
                            .accessibilityLabel(Text("Modyfikacje przepisu"))
                        }
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel(Text("Edit"))
                    }
                }
            }
            .sheet(item: $activeModIntent) { intent in
                RecipeModificationsSheet(
                    recipe: recipe,
                    intent: intent,
                    onDismiss: { activeModIntent = nil }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $isPortionSheetPresented) {
                RecipePortionSheet(
                    recipe: recipe,
                    onSave: { items in
                        isPortionSheetPresented = false
                        onCook(items)
                    },
                    onDismiss: { isPortionSheetPresented = false },
                    mealAnalyzer: mealAnalyzer,
                    entitlementsStore: entitlementsStore,
                    paywallCoordinator: paywallCoordinator,
                    usageMeter: usageMeter
                )
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text(String.localizedStringWithFormat(L("%lld porcje"), recipe.servings))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                if recipe.cookCount > 0 {
                    Text(String.localizedStringWithFormat(L("Cooked %lld times"), recipe.cookCount))
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
        }
    }

    private func summaryCard(_ text: String) -> some View {
        Card {
            Text(text)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private var nutritionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text(servingsLabel)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if servings != 1 {
                        Text(String(format: "×%.1f", servings))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.primary)
                            .padding(.horizontal, Tokens.Space.sm)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Tokens.Palette.primarySoft))
                    }
                }
                if (recipe.caloriesPerServing ?? 0) > 0 {
                    HStack(spacing: Tokens.Space.lg) {
                        macroPill(
                            label: "kcal",
                            grams: (recipe.caloriesPerServing ?? 0) * servings,
                            color: Tokens.Palette.primary
                        )
                        macroPill(
                            label: "B",
                            grams: (recipe.proteinPerServing ?? 0) * servings,
                            color: Tokens.Palette.primary
                        )
                        macroPill(
                            label: "W",
                            grams: (recipe.carbsPerServing ?? 0) * servings,
                            color: Tokens.Palette.warning
                        )
                        macroPill(
                            label: "T",
                            grams: (recipe.fatPerServing ?? 0) * servings,
                            color: Tokens.Palette.accent
                        )
                    }
                } else {
                    Text("Brak danych — dodasz je przez Edytuj.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
    }

    private var servingsLabel: LocalizedStringKey {
        servings == 1 ? "Wartości / porcję" : "Wartości łącznie"
    }

    private var ratingCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Twoja ocena")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if recipe.rating != nil {
                        Button("Clear") {
                            onRate(nil)
                            Haptics.light()
                        }
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                HStack(spacing: Tokens.Space.xs) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            onRate(Double(star))
                            Haptics.light()
                        } label: {
                            let filled = Double(star) <= (recipe.rating ?? 0)
                            Image(systemName: filled ? "star.fill" : "star")
                                .font(.title3)
                                .foregroundStyle(filled ? Tokens.Palette.warning : Tokens.Palette.inkSubtle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(String.localizedStringWithFormat(L("Oceń %lld gwiazdek"), star)))
                    }
                    Spacer()
                }
            }
        }
    }

    private var servingsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Ile porcji teraz?")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text(String(format: "%.1f", servings))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Slider(value: $servings, in: 0.25...Double(recipe.servings * 2), step: 0.25)
                    .tint(Tokens.Palette.primary)
            }
        }
    }

    private var ingredientsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Ingredients")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Button {
                        copyIngredients()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: didCopyIngredients ? "checkmark" : "doc.on.doc")
                            Text(didCopyIngredients ? "Skopiowane" : "Kopiuj")
                        }
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                    }
                    .buttonStyle(.plain)
                    if !checkedIngredients.isEmpty {
                        Button("Clear") {
                            checkedIngredients.removeAll()
                            Haptics.light()
                        }
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                ForEach(recipe.ingredients) { ingredient in
                    ingredientRow(ingredient)
                }
            }
        }
    }

    private func ingredientRow(_ ingredient: RecipeIngredient) -> some View {
        let isChecked = checkedIngredients.contains(ingredient.id)
        return Button {
            if isChecked {
                checkedIngredients.remove(ingredient.id)
            } else {
                checkedIngredients.insert(ingredient.id)
            }
            Haptics.light()
        } label: {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isChecked ? Tokens.Palette.primary : Tokens.Palette.inkSubtle)
                Text(ingredient.name)
                    .font(Tokens.Font.body)
                    .strikethrough(isChecked, color: Tokens.Palette.inkMuted)
                    .foregroundStyle(isChecked ? Tokens.Palette.inkMuted : Tokens.Palette.ink)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var instructionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Instructions")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text(String.localizedStringWithFormat(L("%lld."), index + 1))
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                            .frame(width: 24, alignment: .leading)
                        Text(step)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func similarCard(_ onTap: @escaping (Recipe) -> Void) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("Co podobnego?")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Tokens.Space.sm) {
                        ForEach(similarRecipes) { peer in
                            Button {
                                onTap(peer)
                                Haptics.light()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(peer.title)
                                        .font(Tokens.Font.bodyEmphasized)
                                        .foregroundStyle(Tokens.Palette.ink)
                                        .lineLimit(1)
                                    Text(String.localizedStringWithFormat(L("%lld składn."), peer.ingredients.count))
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
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func copyIngredients() {
        UIPasteboard.general.string = recipe.ingredients.map { "• \($0.name)" }.joined(separator: "\n")
        didCopyIngredients = true
        Haptics.light()
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            didCopyIngredients = false
        }
    }

    /// Plain-text shopping list built from the recipe's ingredients.
    /// Header carries the recipe title + serving count so the recipient
    /// (likely the user, sending themselves a list) has context.
    var shoppingListText: String {
        var lines: [String] = []
        lines.append(
            String.localizedStringWithFormat(
                L("Lista zakupów — %@"),
                recipe.title
            )
        )
        let scaledServings = max(1, Int(servings.rounded()))
        lines.append(
            String.localizedStringWithFormat(
                L("(%lld porcje)"),
                scaledServings
            )
        )
        lines.append("")
        for ingredient in recipe.ingredients {
            lines.append("• \(ingredient.name)")
        }
        return lines.joined(separator: "\n")
    }

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(String.localizedStringWithFormat(L("%lld"), Int(grams)))
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

// swiftlint:enable type_body_length
