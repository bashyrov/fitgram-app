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
        HStack(spacing: 14) {
            MonoIconBox(systemName: mealTypeIcon, style: .outline)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(mealTypeLabel) · \(Self.timeFormatter.string(from: meal.consumedAt))")
                        .font(Tokens.Font.manrope(11, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                    if meal.photoFilename != nil {
                        Image(systemName: "camera.viewfinder")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Tokens.Mono.muted)
                            .accessibilityLabel(Text("Z zdjęciem"))
                    }
                }
                Text(headline)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(meal.totalCaloriesKcal))")
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .contentTransition(.numericText())
                if let rating = meal.rating, rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(Tokens.Mono.fat)
                        Text(String.localizedStringWithFormat(L("%.0f"), rating))
                            .font(Tokens.Font.manrope(11, weight: 800))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                } else {
                    Text("kcal")
                        .font(Tokens.Font.manrope(11, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .monoCard(radius: Tokens.Mono.Radius.tile, padding: nil)
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
