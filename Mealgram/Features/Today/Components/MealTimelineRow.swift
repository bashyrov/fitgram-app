import SwiftUI

struct MealTimelineRow: View {
    let meal: MealEntry

    private static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: LocalizationStore.currentLanguageCode())
        return formatter
    }

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            VStack(spacing: 4) {
                Text(Self.timeFormatter.string(from: meal.consumedAt))
                    .font(Tokens.Font.subheadline.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(mealTypeLabel)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                if meal.photoFilename != nil {
                    Image(systemName: "camera.fill")
                        .font(.caption2)
                        .foregroundStyle(Tokens.Palette.primary)
                        .accessibilityLabel(Text("Z zdjęciem"))
                }
            }
            .frame(width: 58, alignment: .center)

            RoundedRectangle(cornerRadius: 999, style: .continuous)
                .fill(Tokens.Palette.primary.opacity(0.18))
                .frame(width: 3, height: 42)

            VStack(alignment: .leading, spacing: 3) {
                Text(headline)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 3) {
                Text(String.localizedStringWithFormat(L("%lld kcal"), Int(meal.totalCaloriesKcal)))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
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
        .padding(Tokens.Space.md)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.82))
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
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
}
