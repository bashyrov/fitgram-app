import SwiftUI

/// Grid of every catalog entry — earned ones light up, locked ones stay
/// muted. Drops into the Profile screen.
struct AchievementsSection: View {
    let earnedKindsToDate: [String: Date]

    @State private var selected: AchievementSelection?
    @AppStorage("profile.achievements.earnedOnly") private var earnedOnly = false

    private struct AchievementSelection: Identifiable {
        let id: String
        let definition: AchievementDefinition
        let earnedAt: Date?
    }

    private let columns = [
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

    private var visibleDefinitions: [AchievementDefinition] {
        let sorted = AchievementCatalog.all.sorted(by: { $0.order < $1.order })
        if earnedOnly {
            return sorted.filter { earnedKindsToDate[$0.id] != nil }
        }
        return sorted
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Text("Odznaki")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    Text("\(earnedKindsToDate.count) / \(AchievementCatalog.all.count)")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                if !earnedKindsToDate.isEmpty {
                    Toggle("Pokaż tylko zdobyte", isOn: $earnedOnly)
                        .font(Tokens.Font.footnote)
                        .tint(Tokens.Palette.primary)
                }
                LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
                    ForEach(visibleDefinitions, id: \.id) { definition in
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
}
