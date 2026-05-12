import SwiftUI

/// Read-only view of a saved recipe with a "cook" CTA that scales the per-
/// serving nutrition and pipes it through `MealSaving`.
struct RecipeDetailView: View {
    let recipe: Recipe
    let onCook: (Double) -> Void
    let onEdit: () -> Void
    let onDismiss: () -> Void

    @State private var servings: Double = 1

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
                        servingsCard
                        if !recipe.ingredients.isEmpty {
                            ingredientsCard
                        }
                        if !recipe.instructions.isEmpty {
                            instructionsCard
                        }
                        PrimaryButton(title: "Ugotuj i dodaj do dziennika", systemImage: "checkmark") {
                            onCook(servings)
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
                    Button("Zamknij", action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Tokens.Space.sm) {
                        if !recipe.ingredients.isEmpty {
                            ShareLink(
                                item: shoppingListText,
                                subject: Text("Lista zakupów — \(recipe.title)"),
                                preview: SharePreview(
                                    "Lista zakupów — \(recipe.title)",
                                    icon: Image(systemName: "cart")
                                )
                            ) {
                                Image(systemName: "cart")
                            }
                            .accessibilityLabel(Text("Lista zakupów"))
                        }
                        Button {
                            onEdit()
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .accessibilityLabel(Text("Edytuj"))
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                Text("\(recipe.servings) porcje")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                if recipe.cookCount > 0 {
                    Text("Ugotowane \(recipe.cookCount) razy")
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
                Text("Wartości / porcję")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                if (recipe.caloriesPerServing ?? 0) > 0 {
                    HStack(spacing: Tokens.Space.lg) {
                        macroPill(label: "kcal", grams: recipe.caloriesPerServing ?? 0, color: Tokens.Palette.primary)
                        macroPill(label: "B", grams: recipe.proteinPerServing ?? 0, color: Tokens.Palette.primary)
                        macroPill(label: "W", grams: recipe.carbsPerServing ?? 0, color: Tokens.Palette.warning)
                        macroPill(label: "T", grams: recipe.fatPerServing ?? 0, color: Tokens.Palette.accent)
                    }
                } else {
                    Text("Brak danych — dodasz je przez Edytuj.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
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
                Text("Składniki")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(recipe.ingredients) { ingredient in
                    HStack {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(ingredient.name)
                            .font(Tokens.Font.body)
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                    }
                }
            }
        }
    }

    private var instructionsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Instrukcje")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text("\(index + 1).")
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

    /// Plain-text shopping list built from the recipe's ingredients.
    /// Header carries the recipe title + serving count so the recipient
    /// (likely the user, sending themselves a list) has context.
    var shoppingListText: String {
        var lines: [String] = []
        lines.append("Lista zakupów — \(recipe.title)")
        let scaledServings = max(1, Int(servings.rounded()))
        lines.append("(\(scaledServings) porcje)")
        lines.append("")
        for ingredient in recipe.ingredients {
            lines.append("• \(ingredient.name)")
        }
        return lines.joined(separator: "\n")
    }

    private func macroPill(label: LocalizedStringKey, grams: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(Int(grams))")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
