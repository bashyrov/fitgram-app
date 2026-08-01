import SwiftUI

struct OlaSummaryHero: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            header
            Text(L(recommendations.summary))
                .font(.system(size: 21, weight: .bold, design: .rounded))
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
        .shadow(color: Tokens.Palette.accent.opacity(0.12), radius: 22, x: 0, y: 12)
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.accent,
                                Tokens.Palette.accent.opacity(0.7),
                                Tokens.Palette.primary.opacity(0.8),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: Tokens.Palette.accent.opacity(0.45), radius: 12, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Twój asystent AI"))
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
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
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.62))
        )
    }

    private var background: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.74))
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.30))
                .frame(width: 180, height: 180)
                .blur(radius: 70)
                .offset(x: 110, y: -90)
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.22))
                .frame(width: 160, height: 160)
                .blur(radius: 70)
                .offset(x: -100, y: 90)
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct OlaWarningsBlock: View {
    let warnings: [String]

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: Tokens.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(L(warning))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Tokens.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Tokens.Palette.warning.opacity(0.15))
                )
            }
        }
    }
}

struct OlaTipsList: View {
    let tips: [RecommendationTip]

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(L("Wskazówki na dziś"))
                .font(Tokens.Font.headline)
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
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary.opacity(0.20),
                                Tokens.Palette.accent.opacity(0.20),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
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
                .fill(Tokens.Palette.surface.opacity(0.86))
        }
        .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
    }
}

struct OlaFactsHeader: View {
    let count: Int

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Biblioteka faktów")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.ink)
                Text("\(count) krótkich wskazówek")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            Image(systemName: "book.closed.fill")
                .foregroundStyle(Tokens.Palette.primary)
        }
        .padding(.bottom, Tokens.Space.xs)
    }
}

struct OlaCollapsedFactRow: View {
    let fact: NutritionFact

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Self.tint(for: fact.category).opacity(0.14))
                    .frame(width: 38, height: 38)
                Text(fact.icon)
                    .font(.system(size: 20))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(fact.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.leading)
                Text(FactCard.localizedCategory(fact.category))
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Self.tint(for: fact.category))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.86))
        }
        .shadow(color: Color.black.opacity(0.03), radius: 9, x: 0, y: 4)
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
