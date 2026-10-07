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
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    MonoH1(text: recipe.title, sub: headerSubtitle, kicker: L("Przepis"))
                        .padding(.bottom, 4)
                    if let summary = recipe.summary, !summary.isEmpty {
                        summaryCard(summary)
                    }
                    nutritionCard
                    servingsCard
                    ratingCard
                    if !recipe.ingredients.isEmpty {
                        ingredientsSection
                    }
                    if !recipe.instructions.isEmpty {
                        instructionsSection
                    }
                    if let minutes = recipe.cookMinutes, minutes > 0 {
                        CookTimerCard(cookMinutes: minutes)
                    }
                    if !recipe.ingredients.isEmpty {
                        modificationsRow
                    }
                    if !similarRecipes.isEmpty, let onSelectSimilar {
                        similarSection(onSelectSimilar)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 24)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij"), action: onDismiss)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MonoNavText(title: L("Edit"), emphasized: true, action: onEdit)
                }
            }
            .safeAreaInset(edge: .bottom) {
                MonoBottomBar {
                    MonoButton(title: L("Ugotuj i dodaj do dziennika"), kind: .dark, icon: "fork.knife") {
                        isPortionSheetPresented = true
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

    private var headerSubtitle: String {
        var parts = [String.localizedStringWithFormat(L("%lld porcje"), recipe.servings)]
        if recipe.cookCount > 0 {
            parts.append(String.localizedStringWithFormat(L("Cooked %lld times"), recipe.cookCount))
        }
        return parts.joined(separator: " · ")
    }

    private func summaryCard(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Font.manrope(14, weight: 600))
            .foregroundStyle(Tokens.Palette.ink)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .monoCard(padding: 16)
    }

    private var nutritionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(servingsLabel)
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.heroMuted)
                Spacer()
                Text(String(format: "× %@", servingsText))
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(Capsule().fill(Tokens.Mono.heroLine))
            }
            if (recipe.caloriesPerServing ?? 0) > 0 {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(((recipe.caloriesPerServing ?? 0) * servings).rounded()))")
                        .font(Tokens.Font.monoNumber(52))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                    Text("kcal")
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                }
                MonoMacroRow(
                    protein: (recipe.proteinPerServing ?? 0) * servings,
                    carbs: (recipe.carbsPerServing ?? 0) * servings,
                    fat: (recipe.fatPerServing ?? 0) * servings,
                    dark: true
                )
            } else {
                Text("Brak danych — dodasz je przez Edytuj.")
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private var servingsText: String {
        String(format: "%g", servings)
    }

    private var servingsLabel: LocalizedStringKey {
        servings == 1 ? "Wartości / porcję" : "Wartości łącznie"
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MonoLabel(text: L("Twoja ocena"))
                Spacer()
                if recipe.rating != nil {
                    Button {
                        onRate(nil)
                        Haptics.light()
                    } label: {
                        Text("Clear")
                            .font(Tokens.Font.manrope(12, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        onRate(Double(star))
                        Haptics.light()
                    } label: {
                        let filled = Double(star) <= (recipe.rating ?? 0)
                        Image(systemName: filled ? "star.fill" : "star")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(filled ? Tokens.Mono.fat : Tokens.Mono.line2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String.localizedStringWithFormat(L("Oceń %lld gwiazdek"), star)))
                }
                Spacer()
            }
        }
        .monoCard(padding: 16)
    }

    private var servingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                MonoLabel(text: L("Ile porcji teraz?"))
                Spacer()
                Text(servingsText)
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $servings, in: 0.25...Double(max(1, recipe.servings * 2)), step: 0.25)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text("0.25")
                    Spacer()
                    Text("\(max(1, recipe.servings * 2))")
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .monoCard(padding: 16)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Ingredients")) {
                HStack(spacing: 6) {
                    if !checkedIngredients.isEmpty {
                        Button {
                            checkedIngredients.removeAll()
                            Haptics.light()
                        } label: {
                            Text("Clear")
                                .font(Tokens.Font.manrope(12, weight: 700))
                                .foregroundStyle(Tokens.Mono.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        copyIngredients()
                    } label: {
                        Image(systemName: didCopyIngredients ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(didCopyIngredients ? L("Skopiowane") : L("Kopiuj")))
                    ShareLink(
                        item: shoppingListText,
                        subject: Text(String.localizedStringWithFormat(L("Shopping list — %@"), recipe.title)),
                        preview: SharePreview(
                            String.localizedStringWithFormat(L("Shopping list — %@"), recipe.title),
                            icon: Image(systemName: "cart")
                        )
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "cart")
                                .font(.system(size: 12, weight: .bold))
                            Text("Lista zakupów")
                                .lineLimit(1)
                        }
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
                    }
                    .accessibilityLabel(Text("Lista zakupów"))
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 6)
            .padding(.bottom, 12)
            VStack(spacing: 0) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                    if index > 0 {
                        MonoRowDivider(inset: 16)
                    }
                    ingredientRow(ingredient)
                }
            }
            .monoRowsCard()
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
            HStack(spacing: 12) {
                Text(ingredient.name)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .strikethrough(isChecked, color: Tokens.Mono.muted)
                    .foregroundStyle(isChecked ? Tokens.Mono.muted : Tokens.Palette.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isChecked ? Tokens.Palette.ink : Color.clear)
                    .frame(width: 26, height: 26)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Tokens.Palette.ink, lineWidth: 2)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Tokens.Mono.onHero)
                            .opacity(isChecked ? 1 : 0)
                    )
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }

    private var instructionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Instructions"))
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 12)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("\(index + 1).")
                            .font(Tokens.Font.monoNumber(18))
                            .foregroundStyle(Tokens.Mono.muted)
                        Text(step)
                            .font(Tokens.Font.manrope(14, weight: 600))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .monoCard(padding: 16)
        }
    }

    private var modificationsRow: some View {
        Menu {
            ForEach(RecipeModificationEngine.Intent.allCases, id: \.self) { intent in
                Button {
                    activeModIntent = intent
                } label: {
                    Label(intent.label, systemImage: intent.symbol)
                }
            }
        } label: {
            VStack(spacing: 0) {
                MonoRow(
                    icon: "sparkles",
                    title: L("Modyfikacje przepisu"),
                    sub: RecipeModificationEngine.Intent.allCases.map(\.label).joined(separator: ", ")
                )
            }
            .monoRowsCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Modyfikacje przepisu"))
    }

    private func similarSection(_ onTap: @escaping (Recipe) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: L("Co podobnego?"))
                .padding(.horizontal, 6)
                .padding(.top, 6)
                .padding(.bottom, 12)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(similarRecipes) { peer in
                        Button {
                            onTap(peer)
                            Haptics.light()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(peer.title)
                                    .font(Tokens.Font.manrope(14, weight: 800))
                                    .foregroundStyle(Tokens.Palette.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                Text(String.localizedStringWithFormat(L("%lld składn."), peer.ingredients.count))
                                    .font(Tokens.Font.manrope(12, weight: 600))
                                    .foregroundStyle(Tokens.Mono.muted)
                            }
                            .padding(12)
                            .frame(width: 150, alignment: .leading)
                            .monoCard(radius: 18, padding: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollClipDisabled()
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

}

// swiftlint:enable type_body_length
