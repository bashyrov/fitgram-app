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
            ZStack {
                factsBackground
                ScrollView {
                    LazyVStack(spacing: Tokens.Space.md) {
                        if let highlightedFact {
                            dailyFactHero(highlightedFact)
                        }
                        OlaFactsHeader(count: filteredFacts.count)
                        categoryFilterStrip
                        ForEach(filteredFacts) { fact in
                            factRow(fact)
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.top, Tokens.Space.md)
                    .padding(.bottom, Tokens.Space.xxl)
                }
            }
            .navigationTitle(Text(factsTitle))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Close"), action: onDismiss)
                }
            }
        }
    }

    private var factsBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.58))
                .frame(width: 330, height: 330)
                .blur(radius: 92)
                .offset(x: -150, y: -210)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 105)
                .offset(x: 150, y: -90)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 110)
                .offset(x: 80, y: 260)
        }
        .ignoresSafeArea()
    }

    private func dailyFactHero(_ fact: NutritionFact) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            HStack {
                Label(factOfDayTitle, systemImage: "lightbulb.fill")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                Spacer()
                Text(FactCard.localizedCategory(fact.category))
                    .font(Tokens.Font.caption.weight(.bold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            FactCard(fact: fact, highlighted: true)
        }
    }

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                filterChip(label: L("All"), isSelected: categoryFilter == nil) {
                    categoryFilter = nil
                    expandedFactID = highlightedFact?.id
                }
                ForEach(NutritionFact.Category.allCases) { category in
                    filterChip(
                        label: FactCard.localizedCategory(category),
                        isSelected: categoryFilter == category
                    ) {
                        categoryFilter = (categoryFilter == category) ? nil : category
                        expandedFactID = categoryFilter == nil ? highlightedFact?.id : nil
                    }
                }
            }
            .padding(4)
        }
        .background(.ultraThinMaterial, in: Capsule())
        .background(Capsule().fill(Tokens.Palette.surface.opacity(0.72)))
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            withAnimation(Tokens.Motion.gentle) { action() }
        } label: {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Tokens.Palette.ink)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, 8)
                .background(Capsule().fill(isSelected ? Tokens.Palette.primary : Color.clear))
        }
        .buttonStyle(.plain)
    }

    private var filteredFacts: [NutritionFact] {
        guard let categoryFilter else { return NutritionFactCatalog.all }
        return NutritionFactCatalog.all.filter { $0.category == categoryFilter }
    }

    private var factsTitle: String {
        TL(pl: "Fakty", en: "Facts", uk: "Факти", ru: "Факты", es: "Datos")
    }

    private var factOfDayTitle: String {
        TL(pl: "Fakt dnia", en: "Fact of the day", uk: "Факт дня", ru: "Факт дня", es: "Dato del día")
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
