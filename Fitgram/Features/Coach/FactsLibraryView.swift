import SwiftUI

/// Standalone nutrition facts surface. This intentionally lives outside
/// `OlaTipsView`: facts are educational library content, while Ola is a
/// personal coach.
@MainActor
struct FactsLibraryView: View {
    let highlightedFact: NutritionFact?
    let initialCategory: NutritionFact.Category?
    let onDismiss: () -> Void

    @State private var categoryFilter: NutritionFact.Category?
    @State private var expandedFactID: String?

    init(
        highlightedFact: NutritionFact?,
        initialCategory: NutritionFact.Category?,
        onDismiss: @escaping () -> Void
    ) {
        self.highlightedFact = highlightedFact
        self.initialCategory = initialCategory
        self.onDismiss = onDismiss
        self._categoryFilter = State(initialValue: initialCategory)
        self._expandedFactID = State(initialValue: highlightedFact?.id)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    OlaFactsHeader(count: filteredFacts.count)
                    categoryFilterStrip
                        .padding(.top, 14)
                    VStack(spacing: 8) {
                        if let highlightedFact {
                            FactCard(fact: highlightedFact, highlighted: true)
                        }
                        ForEach(filteredFacts) { fact in
                            factRow(fact)
                        }
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 30)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(factsTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
        }
    }

    /// Wrapping chip cloud (lib `chips(…, wrapit=True)`).
    private var categoryFilterStrip: some View {
        FlowLayout(spacing: 6) {
            MonoChip(title: L("All"), isSelected: categoryFilter == nil) {
                select {
                    categoryFilter = nil
                    expandedFactID = highlightedFact?.id
                }
            }
            ForEach(NutritionFact.Category.allCases) { category in
                MonoChip(title: FactCard.localizedCategory(category), isSelected: categoryFilter == category) {
                    select {
                        categoryFilter = (categoryFilter == category) ? nil : category
                        expandedFactID = categoryFilter == nil ? highlightedFact?.id : nil
                    }
                }
            }
        }
    }

    private func select(_ action: () -> Void) {
        Haptics.light()
        withAnimation(Tokens.Motion.gentle) { action() }
    }

    private var filteredFacts: [NutritionFact] {
        guard let categoryFilter else { return NutritionFactCatalog.all }
        return NutritionFactCatalog.all.filter { $0.category == categoryFilter }
    }

    private var factsTitle: String {
        TL(pl: "Fakty", en: "Facts", uk: "Факти", ru: "Факты", es: "Datos")
    }

    private func factRow(_ fact: NutritionFact) -> some View {
        let isExpanded = expandedFactID == fact.id
        return Button {
            withAnimation(Tokens.Motion.gentle) {
                expandedFactID = isExpanded ? nil : fact.id
            }
            Haptics.light()
        } label: {
            if isExpanded {
                FactCard(fact: fact, highlighted: false)
            } else {
                OlaCollapsedFactRow(fact: fact)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
