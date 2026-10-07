import SwiftUI

/// Reusable card used by the standalone facts library and the Today
/// fact-of-day preview. Design D (lib `fact`): category label + trailing
/// mark, 19 pt display title, 14/600 body. Highlighted = dark hero with "Fakt dnia" pill.
struct FactCard: View {
    let fact: NutritionFact
    /// "Highlighted" style is used for today's fact: dark hero surface with
    /// the "Fakt dnia" pill. Catalog rows use the plain card style.
    var highlighted: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: highlighted ? 14 : 12) {
            HStack(alignment: .center, spacing: 8) {
                MonoLabel(text: Self.localizedCategory(fact.category), onHero: highlighted)
                Spacer(minLength: 0)
                trailingMark
            }
            Text(fact.title)
                .font(Tokens.Font.monoDisplay(19))
                .foregroundStyle(highlighted ? Tokens.Mono.onHero : Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(fact.body)
                .font(Tokens.Font.manrope(14, weight: 600))
                .foregroundStyle(highlighted ? Tokens.Mono.heroMuted : Tokens.Mono.muted)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
            if let source = fact.source {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.system(size: 10, weight: .semibold))
                    Text(source)
                        .font(Tokens.Font.manrope(11, weight: 700))
                }
                .foregroundStyle(highlighted ? Tokens.Mono.heroMuted : Tokens.Mono.muted)
            }
        }
        .padding(highlighted ? 18 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(
                cornerRadius: highlighted ? Tokens.Mono.Radius.hero : Tokens.Mono.Radius.card,
                style: .continuous
            )
            .fill(highlighted ? Tokens.Mono.hero : Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(
                cornerRadius: highlighted ? Tokens.Mono.Radius.hero : Tokens.Mono.Radius.card,
                style: .continuous
            )
            .stroke(highlighted ? Color.clear : Tokens.Mono.line, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var trailingMark: some View {
        if highlighted {
            Text(TL(pl: "Fakt dnia", en: "Fact of the day", uk: "Факт дня", ru: "Факт дня", es: "Dato del día"))
                .font(Tokens.Font.manrope(11, weight: 900))
                .foregroundStyle(Tokens.Mono.onHi)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Tokens.Mono.hi))
        } else {
            Text(fact.icon)
                .font(.system(size: 16))
                .accessibilityHidden(true)
        }
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
