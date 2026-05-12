import SwiftUI

/// Lifetime counters — total meals, recipes, weight logs, achievements.
/// Optional "Z nami od …" footer if the User row carries a createdAt.
struct ProfileStatsCard: View {
    let summary: ProfileStatsService.Summary

    private static let memberFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                Text("Razem")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                    ],
                    spacing: Tokens.Space.md
                ) {
                    tile(symbol: "fork.knife", value: summary.totalMeals, caption: "posiłków")
                    tile(symbol: "book.fill", value: summary.totalRecipes, caption: "przepisów")
                    tile(symbol: "scalemass.fill", value: summary.totalWeightEntries, caption: "wpisów wagi")
                    tile(symbol: "trophy.fill", value: summary.totalAchievements, caption: "odznak")
                }
                if let memberSince = summary.memberSince {
                    Text("Z nami od \(Self.memberFormatter.string(from: memberSince).capitalized)")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
            }
        }
    }

    private func tile(symbol: String, value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(caption)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Text("\(value)")
                .font(Tokens.Font.counter)
                .foregroundStyle(Tokens.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.primarySoft.opacity(0.5))
        )
    }
}
