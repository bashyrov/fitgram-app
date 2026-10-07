import SwiftUI

/// Lifetime counters — total meals, recipes, weight logs, achievements.
/// Optional "Z nami od …" footer if the User row carries a createdAt.
struct ProfileStatsCard: View {
    let summary: ProfileStatsService.Summary

    private static var memberFormatter: DateFormatter {

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.dateFormat = "LLLL yyyy"
        return formatter

    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Razem")
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.muted)
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8),
                    ],
                    spacing: 8
                ) {
                    tile(symbol: "fork.knife", value: summary.totalMeals, caption: "posiłków")
                    tile(symbol: "book.fill", value: summary.totalRecipes, caption: "przepisów")
                    tile(symbol: "scalemass.fill", value: summary.totalWeightEntries, caption: "wpisów wagi")
                    tile(symbol: "trophy.fill", value: summary.totalAchievements, caption: "odznak")
                }
                if summary.totalCaloriesKcal > 0 {
                    Text(
                        String.localizedStringWithFormat(
                            L("Total: %@ kcal"), Self.kcalString(summary.totalCaloriesKcal))
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                }
                if summary.totalRecipeCooks > 0 {
                    Text(String.localizedStringWithFormat(L("Cooked: %lld×"), summary.totalRecipeCooks))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                if let avg = summary.averageMealRating {
                    Text(String.localizedStringWithFormat(L("Average meal rating: ⭐ %.1f / 5"), avg))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                if summary.longestStreakLength > 0 {
                    Text(String.localizedStringWithFormat(L("Streak record: 🔥 %lld days"), summary.longestStreakLength))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                if summary.totalWaterMilliliters > 0 {
                    Text(
                        String.localizedStringWithFormat(
                            L("Water drunk: 💧 %@ L"), Self.litersString(summary.totalWaterMilliliters))
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                }
                if let memberSince = summary.memberSince {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(
                            String.localizedStringWithFormat(
                                L("With us since %@"), Self.memberFormatter.string(from: memberSince).capitalized)
                        )
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        if let daysWithUs = Self.daysSince(memberSince) {
                            Text(daysWithUsLabel(daysWithUs))
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Mono.muted)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
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

    /// Day-count label localised via xcstrings.
    static func daysWithUsLabel(_ days: Int) -> String {
        switch days {
        case 0: return L("You joined today")
        case 1: return L("Day 1 with us")
        default:
            let format = L("%lld days with us")
            return String.localizedStringWithFormat(format, days)
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
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: liters)) ?? "\(liters)"
    }

    /// Formats large kcal totals with thousands separators so "172000"
    /// reads as "172 000" — easier to scan at a glance.
    private static func kcalString(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func tile(symbol: String, value: Int, caption: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(caption)
                .font(Tokens.Font.manrope(11, weight: 800))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Mono.muted)
                .lineLimit(1)
            Text("\(value)")
                .font(Tokens.Font.monoNumber(24))
                .foregroundStyle(Tokens.Palette.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoTile()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(caption))
        .accessibilityValue(Text("\(value)"))
    }
}
