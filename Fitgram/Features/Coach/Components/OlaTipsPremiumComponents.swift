import SwiftUI

struct OlaSummaryHero: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            header
            Text(L(recommendations.summary))
                .font(Tokens.Font.manrope(21, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            if !recommendations.nextSteps.isEmpty {
                nextStep
            }
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background { background }
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Tokens.Mono.hi)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                        .fill(Tokens.Mono.hero)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Twój asystent AI"))
                    .font(Tokens.Font.monoDisplay(22))
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer(minLength: 0)
        }
    }

    private var subtitle: String {
        guard let lastUpdated else { return L("Twoje spersonalizowane porady") }
        return L("Aktualne · ") + lastUpdated.formatted(.relative(presentation: .named))
    }

    private var nextStep: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "arrow.right.circle.fill")
                .foregroundStyle(Tokens.Palette.primary)
            Text(L(recommendations.nextSteps))
                .font(Tokens.Font.footnote.weight(.semibold))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(2)
        }
        .padding(Tokens.Space.md)
        .monoSurface(radius: 18)
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Tokens.Palette.surface)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Tokens.Palette.surface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct OlaWarningsBlock: View {
    let warnings: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Tokens.Mono.fat)
                        .frame(width: 20)
                    Text(L(warning))
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .monoCard(padding: 16)
    }
}

struct OlaTipsList: View {
    let tips: [RecommendationTip]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(L("Wskazówki na dziś"))
                .font(Tokens.Font.monoDisplay(18))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, 2)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(tips) { tip in
                    OlaTipRow(tip: tip)
                }
            }
        }
    }
}

private struct OlaTipRow: View {
    let tip: RecommendationTip

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        Tokens.Palette.primary.opacity(0.20)
                    )
                    .frame(width: 56, height: 56)
                Text(tip.icon)
                    .font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(L(tip.title))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L(tip.description))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Palette.surface)
        }
    }
}

/// Facts library headline (lib `h1`): big display title + count subtitle.
struct OlaFactsHeader: View {
    let count: Int

    var body: some View {
        MonoH1(
            text: L("Facts library"),
            sub: String.localizedStringWithFormat(L("%lld short tips"), count)
        )
    }
}

/// Collapsed fact (tap to expand into `FactCard`): same card chrome as the expanded
/// fact, with the category label, display title and a chevron.
struct OlaCollapsedFactRow: View {
    let fact: NutritionFact

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 8) {
                MonoLabel(text: FactCard.localizedCategory(fact.category))
                Spacer(minLength: 0)
                Text(fact.icon)
                    .font(.system(size: 16))
                    .accessibilityHidden(true)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            Text(fact.title)
                .font(Tokens.Font.monoDisplay(19))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .monoCard(padding: 16)
    }

    static func tint(for category: NutritionFact.Category) -> Color {
        switch category {
        case .calories, .metabolism, .carbs, .fats:
            return Tokens.Palette.warning
        case .weightLoss, .training, .hydration:
            return Tokens.Palette.primary
        case .weightGain, .protein, .psychology:
            return Tokens.Palette.accent
        case .fiber, .polishCuisine:
            return Tokens.Palette.success
        }
    }
}
