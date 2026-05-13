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
                if summary.totalCaloriesKcal > 0 {
                    Text("Łącznie: \(Self.kcalString(summary.totalCaloriesKcal)) kcal")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                if summary.totalRecipeCooks > 0 {
                    Text("Ugotowane: \(summary.totalRecipeCooks)×")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                if let avg = summary.averageMealRating {
                    Text(String(format: "Średnia ocena posiłku: ⭐ %.1f / 5", avg))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.warning)
                }
                if summary.longestStreakLength > 0 {
                    Text("Rekord serii: 🔥 \(summary.longestStreakLength) dni")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.warning)
                }
                if summary.totalWaterMilliliters > 0 {
                    Text("Wypita woda: 💧 \(Self.litersString(summary.totalWaterMilliliters)) L")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                if let memberSince = summary.memberSince {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Z nami od \(Self.memberFormatter.string(from: memberSince).capitalized)")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                        if let daysWithUs = Self.daysSince(memberSince) {
                            Text(daysWithUsLabel(daysWithUs))
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.primary)
                        }
                    }
                }
            }
        }
    }

    /// Day count from a stored date — nil if Calendar can't resolve, or
    /// if the result would be negative (clock drift / restored backup).
    static func daysSince(_ date: Date, now: Date = Date()) -> Int? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.startOfDay(for: now)
        guard let days = calendar.dateComponents([.day], from: start, to: end).day,
            days >= 0
        else { return nil }
        return days
    }

    /// Polish day-count label. Singular "1 dzień", plural "N dni".
    /// Pure function so tests can pin down the strings directly.
    static func daysWithUsLabel(_ days: Int) -> String {
        switch days {
        case 0: return "Dzisiaj dołączyłeś"
        case 1: return "1 dzień z nami"
        default: return "\(days) dni z nami"
        }
    }

    private func daysWithUsLabel(_ days: Int) -> String {
        Self.daysWithUsLabel(days)
    }

    /// Renders ml → "L" with one decimal place, Polish comma separator.
    /// 28350 ml → "28,4 L".
    static func litersString(_ milliliters: Int) -> String {
        let liters = Double(milliliters) / 1000
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pl_PL")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: liters)) ?? "\(liters)"
    }

    /// Formats large kcal totals with thousands separators so "172000"
    /// reads as "172 000" — easier to scan at a glance.
    private static func kcalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "pl_PL")
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
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
