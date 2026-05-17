import SwiftUI

/// Reusable card used both for "ciekawostka dnia" highlight on the
/// "Dziś" tab of `OlaTipsView` and as the expanded row in the
/// "Ciekawostki" catalog list. Matches the Ola hero aesthetic — soft
/// rounded card with a gradient ring around the emoji puck.
struct FactCard: View {
    let fact: NutritionFact
    /// "Highlighted" style is used for today's fact: a bit larger emoji,
    /// stronger accent ring. Catalog rows use the plain style.
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                emojiPuck
                VStack(alignment: .leading, spacing: 4) {
                    categoryChip
                    Text(fact.title)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            // Fact bodies stay in Polish source language this pass.
            Text(fact.body)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.ink.opacity(0.85))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if let source = fact.source {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                    Text(source)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                }
                .padding(.top, 2)
            }
        }
        .padding(highlighted ? Tokens.Space.lg : Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: highlighted ? Tokens.Radius.xl : Tokens.Radius.lg,
                style: .continuous
            )
            .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: highlighted ? Tokens.Radius.xl : Tokens.Radius.lg,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: highlighted
                        ? [tint(for: fact.category).opacity(0.55), tint(for: fact.category).opacity(0.10)]
                        : [Tokens.Palette.separator, Tokens.Palette.separator.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: highlighted ? 1.5 : 1
            )
        )
        .mealgramShadow(highlighted ? Tokens.Shadow.float : Tokens.Shadow.card)
    }

    private var emojiPuck: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tint(for: fact.category).opacity(0.30),
                            tint(for: fact.category).opacity(0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: highlighted ? 56 : 44, height: highlighted ? 56 : 44)
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            tint(for: fact.category).opacity(0.65),
                            tint(for: fact.category).opacity(0.20),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
                .frame(width: highlighted ? 56 : 44, height: highlighted ? 56 : 44)
            Text(fact.icon)
                .font(.system(size: highlighted ? 28 : 22))
        }
    }

    private var categoryChip: some View {
        Text(Self.localizedCategory(fact.category))
            .font(.system(size: 10, weight: .heavy))
            .textCase(.uppercase)
            .tracking(1.2)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(tint(for: fact.category))
            .background(
                Capsule().fill(tint(for: fact.category).opacity(0.14))
            )
            .overlay(
                Capsule().strokeBorder(tint(for: fact.category).opacity(0.35), lineWidth: 0.75)
            )
    }

    /// Tint picked from the existing palette — never an invented hex.
    /// Maps the 12-case category enum onto the 4-5 brand colours we
    /// already have so the screen stays visually coherent.
    private func tint(for category: NutritionFact.Category) -> Color {
        switch category {
        case .calories, .metabolism:
            return Tokens.Palette.warning
        case .weightLoss, .training:
            return Tokens.Palette.primary
        case .weightGain, .protein:
            return Tokens.Palette.accent
        case .carbs, .fats:
            return Tokens.Palette.warning
        case .fiber, .polishCuisine:
            return Tokens.Palette.success
        case .hydration:
            return Tokens.Palette.primary
        case .psychology:
            return Tokens.Palette.accent
        }
    }

    static func localizedCategory(_ category: NutritionFact.Category) -> String {
        switch category {
        case .calories: return String(localized: "Kalorie")
        case .weightLoss: return String(localized: "Odchudzanie")
        case .weightGain: return String(localized: "Masa")
        case .protein: return String(localized: "Białko")
        case .carbs: return String(localized: "Węglowodany")
        case .fats: return String(localized: "Tłuszcze")
        case .fiber: return String(localized: "Błonnik")
        case .hydration: return String(localized: "Nawodnienie")
        case .metabolism: return String(localized: "Metabolizm")
        case .training: return String(localized: "Trening")
        case .psychology: return String(localized: "Psychologia")
        case .polishCuisine: return String(localized: "Kuchnia PL")
        }
    }
}

#Preview("FactCard") {
    if let fact = NutritionFactCatalog.all.first {
        VStack(spacing: Tokens.Space.lg) {
            FactCard(fact: fact, highlighted: true)
            FactCard(fact: NutritionFactCatalog.all[10])
        }
        .padding(Tokens.Space.lg)
        .background(Tokens.Palette.background)
    }
}
