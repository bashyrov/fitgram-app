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
        GridItem(.flexible(), spacing: Tokens.Space.md),
        GridItem(.flexible(), spacing: Tokens.Space.md),
    ]

    private var definitions: [AchievementDefinition] {
        selectedCategory.filter(AchievementCatalog.all.sorted(by: { $0.order < $1.order }))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    header
                    categoryRail
                    LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
                        ForEach(definitions, id: \.id) { definition in
                            achievementCard(definition)
                        }
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
            .background(Tokens.Palette.background.ignoresSafeArea())
            .navigationTitle(Text("Wszystkie odznaki"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Zamknij") { dismiss() }
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

    private var header: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("\(earnedKindsToDate.count) / \(AchievementCatalog.all.count)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.primary)
            Text("Twoja kolekcja rośnie z każdym realnym nawykiem.")
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.lg)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(AchievementCollectionCategory.allCases) { category in
                    Button {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                    } label: {
                        Label(category.title, systemImage: category.symbol)
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(selectedCategory == category ? .white : Tokens.Palette.ink)
                            .padding(.horizontal, Tokens.Space.md)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? category.tint : Tokens.Palette.surface)
                            )
                    }
                    .buttonStyle(.pressable)
                }
            }
        }
    }

    private func achievementCard(_ definition: AchievementDefinition) -> some View {
        let isEarned = earnedKindsToDate[definition.id] != nil
        return Button {
            selected = AchievementSelection(
                id: definition.id,
                definition: definition,
                earnedAt: earnedKindsToDate[definition.id]
            )
            Haptics.light()
        } label: {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack(alignment: .top) {
                    AchievementMedallion(definition: definition, isEarned: isEarned, size: 58)
                    Spacer(minLength: 0)
                    Text(definition.rarity.title)
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundStyle(definition.rarity.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(definition.rarity.tint.opacity(0.12)))
                }
                Text(definition.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                Text(definition.summary)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
            .padding(Tokens.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isEarned ? Tokens.Palette.surface.opacity(0.88) : Tokens.Palette.surfaceMuted.opacity(0.72))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isEarned ? definition.rarity.tint.opacity(0.28) : .white.opacity(0.24), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
