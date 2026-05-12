import SwiftUI

/// Grid of every catalog entry — earned ones light up, locked ones stay
/// muted. Drops into the Profile screen.
struct AchievementsSection: View {
    let earnedKindsToDate: [String: Date]

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
                LazyVGrid(columns: columns, spacing: Tokens.Space.md) {
                    ForEach(AchievementCatalog.all.sorted(by: { $0.order < $1.order }), id: \.id) { definition in
                        AchievementBadge(
                            definition: definition,
                            isEarned: earnedKindsToDate[definition.id] != nil,
                            earnedAt: earnedKindsToDate[definition.id]
                        )
                    }
                }
            }
        }
    }
}
