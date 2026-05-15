import SwiftUI

struct MealTimelineRow: View {
    let meal: MealEntry

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale.current
        return formatter
    }()

    var body: some View {
        Card {
            HStack(spacing: Tokens.Space.lg) {
                VStack(spacing: 2) {
                    Text(Self.timeFormatter.string(from: meal.consumedAt))
                        .font(Tokens.Font.subheadline)
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
                .frame(width: 56, alignment: .center)
                Divider()
                    .frame(width: 1, height: 36)
                    .overlay(Tokens.Palette.separator)
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
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(meal.totalCaloriesKcal)) kcal")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                    if let rating = meal.rating, rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("\(rating)")
                                .font(Tokens.Font.caption)
                        }
                        .foregroundStyle(Tokens.Palette.warning)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(a11yLabel))
        .accessibilityValue(Text("\(Int(meal.totalCaloriesKcal)) kilokalorii"))
    }

    private var a11yLabel: String {
        let parts = [Self.timeFormatter.string(from: meal.consumedAt), headline]
        return parts.joined(separator: ", ")
    }

    private var headline: String {
        if let first = meal.items.first?.name { return first }
        return String(localized: "Posiłek")
    }

    private var subtitle: String {
        var parts: [String] = []
        if meal.items.count > 1 {
            parts.append(String(localized: "i \(meal.items.count - 1) więcej"))
        } else {
            parts.append(
                String(
                    format: "%.0f g · %.0f g B · %.0f g W · %.0f g T",
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
