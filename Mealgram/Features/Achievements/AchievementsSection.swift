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
        GridItem(.flexible(), spacing: Tokens.Space.md),
        GridItem(.flexible(), spacing: Tokens.Space.md),
        GridItem(.flexible(), spacing: Tokens.Space.md),
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
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
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

    private var collectionHero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kolekcja odznak")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Kategorie, rzadkość i następne cele w jednym miejscu.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
                Button {
                    isAllPresented = true
                    Haptics.light()
                } label: {
                    Label("Wszystkie", systemImage: "square.grid.2x2.fill")
                        .font(Tokens.Font.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Tokens.Palette.primary))
                }
                .buttonStyle(.pressable)
            }

            HStack(spacing: Tokens.Space.sm) {
                collectionMetric(
                    value: "\(earnedKindsToDate.count)",
                    label: L("zdobyte"),
                    symbol: "checkmark.seal.fill",
                    tint: Tokens.Palette.success
                )
                collectionMetric(
                    value: "\(AchievementCatalog.all.count)",
                    label: L("łącznie"),
                    symbol: "sparkles",
                    tint: Tokens.Palette.primary
                )
                collectionMetric(
                    value: "\(legendaryEarnedCount)",
                    label: L("legendy"),
                    symbol: "crown.fill",
                    tint: Tokens.Palette.warning
                )
            }
        }
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(.white.opacity(0.38), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.10), radius: 22, y: 12)
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(AchievementCollectionCategory.allCases) { category in
                    Button {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                        Haptics.selection()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 12, weight: .bold))
                            Text(category.title)
                                .font(Tokens.Font.caption.weight(.bold))
                        }
                        .foregroundStyle(selectedCategory == category ? .white : Tokens.Palette.ink)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedCategory == category ? category.tint : Tokens.Palette.surface.opacity(0.86))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedCategory == category ? .clear : .white.opacity(0.34), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var nextAwardCard: some View {
        if let nextDefinition {
            let nextIndex =
                sortedDefinitions.firstIndex(where: { $0.id == nextDefinition.id }) ?? earnedKindsToDate.count
            let progress = Double(earnedKindsToDate.count) / Double(max(1, sortedDefinitions.count))
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: Tokens.Space.md) {
                    AchievementMedallion(definition: nextDefinition, isEarned: false, size: 64)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Następna nagroda")
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(Tokens.Palette.primary)
                        Text(nextDefinition.title)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(nextDefinition.summary)
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                ProgressView(value: min(0.98, progress))
                    .tint(Tokens.Palette.primary)
                Text(
                    String.localizedStringWithFormat(
                        L("Krok %@ z %@ w kolekcji"), "\(nextIndex + 1)", "\(sortedDefinitions.count)")
                )
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            }
            .padding(Tokens.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        }
    }

    private var rarityStrip: some View {
        HStack(spacing: Tokens.Space.sm) {
            ForEach(AchievementRarity.allCases) { rarity in
                let earned = earnedDefinitions.filter { $0.rarity == rarity }.count
                VStack(alignment: .leading, spacing: 5) {
                    Image(systemName: rarity.symbol)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(rarity.tint)
                    Text(rarity.title)
                        .font(Tokens.Font.caption.weight(.bold))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("\(earned)")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(rarity.tint.opacity(0.10))
                )
            }
        }
    }

    private var previewGrid: some View {
        LazyVGrid(columns: previewColumns, spacing: Tokens.Space.md) {
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
            AchievementBadge(
                definition: definition,
                isEarned: earnedKindsToDate[definition.id] != nil,
                earnedAt: earnedKindsToDate[definition.id]
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

    private func collectionMetric(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
            Text(label)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tint.opacity(0.10))
        )
    }
}
