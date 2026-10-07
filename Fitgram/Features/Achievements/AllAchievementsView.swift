import SwiftUI

struct AllAchievementsView: View {
    let earnedKindsToDate: [String: Date]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedCategory: AchievementCollectionCategory = .all
    @State private var selected: AchievementSelection?

    private struct AchievementSelection: Identifiable {
        let id: String
        let definition: AchievementDefinition
        let earnedAt: Date?
    }

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var definitions: [AchievementDefinition] {
        selectedCategory.filter(AchievementCatalog.all.sorted(by: { $0.order < $1.order }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MonoH1(
                        text: "\(earnedKindsToDate.count) / \(AchievementCatalog.all.count)",
                        sub: L("Twoja kolekcja rośnie z każdym realnym nawykiem."),
                        kicker: L("Odznaki")
                    )
                    categoryRail
                        .padding(.top, 14)
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(definitions, id: \.id) { definition in
                            achievementCard(definition)
                        }
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 34)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .monoNavigationTitle(L("Wszystkie odznaki"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Zamknij")) { dismiss() }
                }
            }
        }
        .sheet(item: $selected) { item in
            AchievementDetailSheet(
                definition: item.definition,
                earnedAt: item.earnedAt,
                onDismiss: { selected = nil }
            )
            .presentationDetents([.fraction(0.45), .medium])
        }
    }

    /// chips(): categories, dark when selected, scrolls horizontally.
    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AchievementCollectionCategory.allCases) { category in
                    MonoChip(title: category.title, isSelected: selectedCategory == category) {
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

    private func achievementCard(_ definition: AchievementDefinition) -> some View {
        Button {
            selected = AchievementSelection(
                id: definition.id,
                definition: definition,
                earnedAt: earnedKindsToDate[definition.id]
            )
            Haptics.light()
        } label: {
            MonoAchievementTile(definition: definition, isEarned: earnedKindsToDate[definition.id] != nil)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Design D badge pieces (shared with AchievementsSection / AchievementDetailSheet)

/// Rounded-square glyph: hero fill + hi symbol when earned, track + muted symbol when locked.
struct MonoAchievementGlyph: View {
    let definition: AchievementDefinition
    let isEarned: Bool
    var size: CGFloat = 56
    var radius: CGFloat = 20
    var symbolSize: CGFloat = 24

    var body: some View {
        Image(systemName: definition.symbol)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(isEarned ? Tokens.Mono.hi : Tokens.Mono.muted)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(isEarned ? Tokens.Mono.hero : Tokens.Mono.track)
            )
            .accessibilityHidden(true)
    }
}

/// Mockup `badge()` tile: 20 pt card, 14×8 padding, 56 pt glyph, 12/800 centred title.
struct MonoAchievementTile: View {
    let definition: AchievementDefinition
    let isEarned: Bool

    var body: some View {
        VStack(spacing: 8) {
            MonoAchievementGlyph(definition: definition, isEarned: isEarned)
            Text(definition.title)
                .font(Tokens.Font.manrope(12, weight: 800))
                .foregroundStyle(isEarned ? Tokens.Palette.ink : Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .lineLimit(2, reservesSpace: true)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .monoSurface(radius: Tokens.Mono.Radius.tile)
        .contentShape(RoundedRectangle(cornerRadius: Tokens.Mono.Radius.tile, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(definition.title))
        .accessibilityValue(Text(isEarned ? L("Zdobyte") : L("Zablokowane")))
        .accessibilityHint(Text(definition.summary))
        .accessibilityAddTraits(.isButton)
    }
}
