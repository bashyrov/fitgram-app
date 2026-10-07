import SwiftUI

/// Profile achievements surface as a collection: category filter,
/// next-award progress, rarity framing, and a dedicated full-screen
/// archive for the whole catalog.
struct AchievementsSection: View {
    let earnedKindsToDate: [String: Date]

    @State private var selected: AchievementSelection?
    @State private var selectedCategory: AchievementCollectionCategory = .all
    @State private var isAllPresented = false

    private struct AchievementSelection: Identifiable {
        let id: String
        let definition: AchievementDefinition
        let earnedAt: Date?
    }

    private let previewColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    init(earned: [Achievement]) {
        self.earnedKindsToDate = Dictionary(
            earned.map { ($0.kind, $0.earnedAt) },
            uniquingKeysWith: { lhs, _ in lhs }
        )
    }

    private var sortedDefinitions: [AchievementDefinition] {
        AchievementCatalog.all.sorted(by: { $0.order < $1.order })
    }

    private var filteredDefinitions: [AchievementDefinition] {
        selectedCategory.filter(sortedDefinitions)
    }

    private var nextDefinition: AchievementDefinition? {
        sortedDefinitions.first { earnedKindsToDate[$0.id] == nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            collectionHero
            categoryRail
            nextAwardCard
            rarityStrip
            previewGrid
        }
        .sheet(item: $selected) { item in
            AchievementDetailSheet(
                definition: item.definition,
                earnedAt: item.earnedAt,
                onDismiss: { selected = nil }
            )
            .presentationDetents([.fraction(0.45), .medium])
        }
        .sheet(isPresented: $isAllPresented) {
            AllAchievementsView(earnedKindsToDate: earnedKindsToDate)
        }
    }

    /// hero(): display title + muted line, "Wszystkie" hi pill, 3 stats over a heroLine divider.
    private var collectionHero: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kolekcja odznak")
                        .font(Tokens.Font.monoDisplay(26))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text("Kategorie, rzadkość i następne cele w jednym miejscu.")
                        .font(Tokens.Font.manrope(14, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                MonoButton(
                    title: L("Wszystkie"), kind: .hi, icon: "square.grid.2x2.fill", height: 36, fullWidth: false
                ) {
                    isAllPresented = true
                    Haptics.light()
                }
            }

            HStack(alignment: .top, spacing: 10) {
                MonoStat(label: L("zdobyte"), value: "\(earnedKindsToDate.count)", dark: true)
                MonoStat(label: L("łącznie"), value: "\(AchievementCatalog.all.count)", dark: true)
                MonoStat(label: L("legendy"), value: "\(legendaryEarnedCount)", dark: true)
            }
            .padding(.top, 14)
            .overlay(alignment: .top) {
                Rectangle().fill(Tokens.Mono.heroLine).frame(height: 1)
            }
        }
        .monoHero(padding: 20)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AchievementCollectionCategory.allCases) { category in
                    MonoChip(
                        title: category.title,
                        icon: category.symbol,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                        Haptics.selection()
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var nextAwardCard: some View {
        if let nextDefinition {
            let nextIndex =
                sortedDefinitions.firstIndex(where: { $0.id == nextDefinition.id }) ?? earnedKindsToDate.count
            let progress = Double(earnedKindsToDate.count) / Double(max(1, sortedDefinitions.count))
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    MonoAchievementGlyph(definition: nextDefinition, isEarned: false)
                    VStack(alignment: .leading, spacing: 2) {
                        MonoLabel(text: L("Następna nagroda"))
                        Text(nextDefinition.title)
                            .font(Tokens.Font.manrope(15, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(nextDefinition.summary)
                            .font(Tokens.Font.manrope(12, weight: 600))
                            .foregroundStyle(Tokens.Mono.muted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                MonoTicks(
                    progress: min(0.98, progress), count: 30, height: 10, fill: Tokens.Mono.strong,
                    empty: Tokens.Mono.track)
                Text(
                    String.localizedStringWithFormat(
                        L("Krok %@ z %@ w kolekcji"), "\(nextIndex + 1)", "\(sortedDefinitions.count)")
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
            }
            .monoCard(padding: 16)
        }
    }

    private var rarityStrip: some View {
        HStack(spacing: 8) {
            ForEach(AchievementRarity.allCases) { rarity in
                let earned = earnedDefinitions.filter { $0.rarity == rarity }.count
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: rarity.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(rarity.tint)
                        MonoLabel(text: rarity.title)
                    }
                    Text("\(earned)")
                        .font(Tokens.Font.monoNumber(22))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                .monoTile()
            }
        }
    }

    private var previewGrid: some View {
        LazyVGrid(columns: previewColumns, spacing: 8) {
            ForEach(Array(filteredDefinitions.prefix(9)), id: \.id) { definition in
                achievementButton(definition)
            }
        }
    }

    private func achievementButton(_ definition: AchievementDefinition) -> some View {
        Button {
            selected = AchievementSelection(
                id: definition.id,
                definition: definition,
                earnedAt: earnedKindsToDate[definition.id]
            )
            Haptics.light()
        } label: {
            MonoAchievementTile(
                definition: definition,
                isEarned: earnedKindsToDate[definition.id] != nil
            )
        }
        .buttonStyle(.plain)
    }

    private var earnedDefinitions: [AchievementDefinition] {
        sortedDefinitions.filter { earnedKindsToDate[$0.id] != nil }
    }

    private var legendaryEarnedCount: Int {
        earnedDefinitions.filter { $0.rarity == .legendary }.count
    }
}
