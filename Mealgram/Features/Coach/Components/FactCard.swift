import SwiftUI

/// Reusable card used by the standalone facts library and the Today
/// fact-of-day preview.
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
            .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(
                cornerRadius: highlighted ? Tokens.Radius.xl : Tokens.Radius.lg,
                style: .continuous
            )
            .fill(Tokens.Palette.surface.opacity(highlighted ? 0.78 : 0.86))
        )
        .shadow(
            color: tint(for: fact.category).opacity(highlighted ? 0.12 : 0.06),
            radius: highlighted ? 18 : 10,
            x: 0,
            y: highlighted ? 10 : 5
        )
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
        case .calories: return L("Calories")
        case .weightLoss: return L("Odchudzanie")
        case .weightGain: return L("Masa")
        case .protein: return L("Protein")
        case .carbs: return L("Węglowodany")
        case .fats: return L("Fats")
        case .fiber: return L("Fiber")
        case .hydration: return L("Nawodnienie")
        case .metabolism: return L("Metabolizm")
        case .training: return L("Trening")
        case .psychology: return L("Psychologia")
        case .polishCuisine: return L("Kuchnia PL")
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
