import SwiftUI

struct MealTimelineRow: View {
    let meal: MealEntry
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    private var palette: AppAccentPalette {
        AppAccentPalette(rawValue: accentRaw) ?? .rose
    }

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter
    }

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                palette.primary.opacity(0.24),
                                palette.accent.opacity(0.10),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: mealTypeIcon)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(palette.primary)
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(mealTypeLabel)
                        .font(Tokens.Font.caption.weight(.bold))
                        .foregroundStyle(palette.primary)
                        .textCase(.uppercase)
                    Text(Self.timeFormatter.string(from: meal.consumedAt))
                        .font(Tokens.Font.caption.weight(.semibold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    if meal.photoFilename != nil {
                        Image(systemName: "camera.viewfinder")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(palette.accent)
                            .accessibilityLabel(Text("Z zdjęciem"))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(headline)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 3) {
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(meal.totalCaloriesKcal)))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(palette.primary)
                    .contentTransition(.numericText())
                if let rating = meal.rating, rating > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                        Text(String.localizedStringWithFormat(L("%.0f"), rating))
                            .font(Tokens.Font.caption)
                    }
                    .foregroundStyle(Tokens.Palette.warning)
                }
            }
        }
        .padding(.horizontal, Tokens.Space.md)
        .padding(.vertical, 14)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            palette.surface.opacity(0.86),
                            palette.primarySoft.opacity(0.45),
                            palette.surfaceMuted.opacity(0.24),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay(alignment: .trailing) {
            Capsule()
                .fill(palette.primary.opacity(0.22))
                .frame(width: 4, height: 34)
                .padding(.trailing, 1)
        }
        .shadow(color: palette.primary.opacity(0.05), radius: 12, x: 0, y: 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(a11yLabel))
        .accessibilityValue(Text(String.localizedStringWithFormat(L("%lld kilokalorii"), Int(meal.totalCaloriesKcal))))
    }

    private var a11yLabel: String {
        let parts = [Self.timeFormatter.string(from: meal.consumedAt), headline]
        return parts.joined(separator: ", ")
    }

    private var headline: String {
        if let first = meal.items.first?.name { return first }
        return L("Posiłek")
    }

    private var subtitle: String {
        var parts: [String] = []
        if meal.items.count > 1 {
            parts.append(String.localizedStringWithFormat(L("and %lld more"), meal.items.count - 1))
        } else {
            let format = L("%.0f g · %.0f g B · %.0f g W · %.0f g T")
            parts.append(
                String.localizedStringWithFormat(
                    format,
                    meal.items.reduce(0) { $0 + $1.quantityGrams },
                    meal.totalProteinGrams,
                    meal.totalCarbsGrams,
                    meal.totalFatGrams
                )
            )
        }
        if !meal.tags.isEmpty {
            parts.append("#" + meal.tags.joined(separator: " #"))
        }
        return parts.joined(separator: " · ")
    }

    private var mealTypeLabel: LocalizedStringKey {
        switch meal.mealType {
        case .breakfast: return "śniadanie"
        case .lunch: return "obiad"
        case .dinner: return "kolacja"
        case .snack: return "przekąska"
        }
    }

    private var mealTypeIcon: String {
        switch meal.mealType {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "fork.knife"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }
}
