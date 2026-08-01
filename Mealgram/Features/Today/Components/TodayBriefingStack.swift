import SwiftUI

struct TodayBriefingStack: View {
    var title: LocalizedStringKey = "Dla Ciebie"
    var symbol: String = "sparkles"
    let fact: NutritionFact?
    let recommendations: Recommendations?
    let recommendationsUpdatedAt: Date?
    let coachInsight: CoachInsight?
    let isOlaLocked: Bool
    let upcomingEvent: CulturalEventService.Upcoming?
    let suggestedRecipe: Recipe?
    let onOpenTips: () -> Void
    let onCoachAction: (CoachInsight.ActionKind) -> Void
    let onDismissInsight: ((CoachInsight) -> Void)?
    let onDismissEvent: () -> Void
    let onCookSuggested: ((Recipe) -> Void)?

    private var hasContent: Bool {
        fact != nil || recommendations != nil || coachInsight != nil
            || isOlaLocked || upcomingEvent != nil || suggestedRecipe != nil
    }

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 0) {
                header
                contentRows
            }
            .padding(Tokens.Space.md)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.74))
            }
            .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 18, x: 0, y: 10)
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Tokens.Palette.accent)
        }
        .padding(.bottom, Tokens.Space.sm)
    }

    @ViewBuilder
    private var contentRows: some View {
        if let recommendations {
            coachPlanRow(recommendations)
        } else if isOlaLocked {
            lockedOlaRow
        }
        if let fact {
            rowDivider(if: recommendations != nil || isOlaLocked)
            factRow(fact)
        }
        if let coachInsight {
            rowDivider(if: recommendations != nil || isOlaLocked || fact != nil)
            insightRow(coachInsight)
        }
        if let upcomingEvent {
            rowDivider(if: recommendations != nil || fact != nil || coachInsight != nil)
            eventRow(upcomingEvent)
        }
        if let suggestedRecipe, let onCookSuggested {
            rowDivider(
                if: recommendations != nil || fact != nil || coachInsight != nil
                    || upcomingEvent != nil
            )
            recipeRow(suggestedRecipe, onCook: { onCookSuggested(suggestedRecipe) })
        }
    }

    private var lockedOlaRow: some View {
        Button(action: onOpenTips) {
            briefingRow(
                icon: "sparkles",
                iconColor: Tokens.Palette.accent,
                title: L("Porady od Oli"),
                body: L("Indywidualne wskazówki AI są dostępne w Pro."),
                badge: L("PRO"),
                accessory: Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            )
            .opacity(0.52)
            .overlay(alignment: .topTrailing) {
                Text("PRO")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Tokens.Palette.primary))
                    .padding(.top, 6)
                    .padding(.trailing, 2)
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Porady od Oli Pro"))
    }

    @ViewBuilder
    private func rowDivider(if isVisible: Bool) -> some View {
        if isVisible {
            Divider()
                .background(Tokens.Palette.separator.opacity(0.6))
                .padding(.leading, 54)
        }
    }

    private func coachPlanRow(_ recommendations: Recommendations) -> some View {
        Button(action: onOpenTips) {
            briefingRow(
                icon: "sparkles",
                iconColor: Tokens.Palette.accent,
                title: L("Porady od Oli"),
                body: L(recommendations.summary),
                accessory: recommendationsAccessory
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Otwórz porady od Oli"))
    }

    private var recommendationsAccessory: some View {
        VStack(alignment: .trailing, spacing: 5) {
            if recommendationsUpdatedAt != nil {
                Circle()
                    .fill(Tokens.Palette.success)
                    .frame(width: 7, height: 7)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private func factRow(_ fact: NutritionFact) -> some View {
        Button(action: onOpenTips) {
            briefingRow(
                iconText: fact.icon,
                iconColor: tint(for: fact.category),
                title: fact.title,
                body: fact.body,
                badge: FactCard.localizedCategory(fact.category),
                accessory: chevron
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Otwórz Ciekawostki"))
    }

    private func insightRow(_ insight: CoachInsight) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            iconPuck(systemName: symbol(for: insight.tone), color: tint(for: insight.tone))
            VStack(alignment: .leading, spacing: 5) {
                Text(L(insight.headline))
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                Text(L(insight.body))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let title = insight.actionTitle, let kind = insight.actionKind {
                    Button {
                        onCoachAction(kind)
                    } label: {
                        Label(L(title), systemImage: "arrow.right")
                            .font(Tokens.Font.caption.weight(.bold))
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            if let onDismissInsight {
                Button {
                    onDismissInsight(insight)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Tokens.Palette.inkSubtle)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Ukryj"))
            }
        }
        .padding(.vertical, Tokens.Space.sm)
    }

    private func eventRow(_ upcoming: CulturalEventService.Upcoming) -> some View {
        briefingRow(
            icon: upcoming.event.symbol,
            iconColor: Tokens.Palette.primary,
            title: L(upcoming.event.name),
            body: L(upcoming.event.foodNote),
            badge: eventBadge(upcoming),
            accessory: Button(action: onDismissEvent) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ukryj"))
        )
    }

    private func recipeRow(_ recipe: Recipe, onCook: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            iconPuck(systemName: "book.closed.fill", color: Tokens.Palette.primary)
            VStack(alignment: .leading, spacing: 5) {
                Text("Favorites")
                    .font(Tokens.Font.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.primary)
                Text(recipe.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text(recipeSubtitle(recipe))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button(action: onCook) {
                Text("Ugotuj")
                    .font(Tokens.Font.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Tokens.Space.md)
                    .frame(height: 34)
                    .background(Capsule().fill(Tokens.Palette.primary))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Text(String.localizedStringWithFormat(L("Ugotuj %@"), recipe.title)))
        }
        .padding(.vertical, Tokens.Space.sm)
    }

    private func briefingRow<Accessory: View>(
        icon: String? = nil,
        iconText: String? = nil,
        iconColor: Color,
        title: String,
        body: String,
        badge: String? = nil,
        accessory: Accessory
    ) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            if let iconText {
                iconPuck(text: iconText, color: iconColor)
            } else {
                iconPuck(systemName: icon ?? "circle.fill", color: iconColor)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: Tokens.Space.xs) {
                    Text(title)
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 9, weight: .heavy))
                            .textCase(.uppercase)
                            .foregroundStyle(iconColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(iconColor.opacity(0.12)))
                    }
                }
                Text(body)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            accessory
        }
        .padding(.vertical, Tokens.Space.sm)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.Palette.inkSubtle)
            .padding(.top, 2)
    }

    private func iconPuck(systemName: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 42, height: 42)
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func iconPuck(text: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 42, height: 42)
            Text(text)
                .font(.system(size: 21))
        }
    }

    private func tint(for category: NutritionFact.Category) -> Color {
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

    private func tint(for tone: CoachInsight.Tone) -> Color {
        switch tone {
        case .encouragement, .suggestion:
            return Tokens.Palette.primary
        case .nudge:
            return Tokens.Palette.warning
        case .celebration:
            return Tokens.Palette.accent
        }
    }

    private func symbol(for tone: CoachInsight.Tone) -> String {
        switch tone {
        case .encouragement:
            return "heart.fill"
        case .suggestion:
            return "lightbulb.fill"
        case .nudge:
            return "bell.fill"
        case .celebration:
            return "sparkles"
        }
    }

    private func eventBadge(_ upcoming: CulturalEventService.Upcoming) -> String {
        if upcoming.isToday { return L("dziś") }
        if upcoming.daysAway == 1 { return L("jutro") }
        return String.localizedStringWithFormat(L("za %lld dni"), upcoming.daysAway)
    }

    private func recipeSubtitle(_ recipe: Recipe) -> String {
        var parts: [String] = []
        if recipe.cookCount > 0 {
            parts.append(String.localizedStringWithFormat(L("Cooked %lld times"), recipe.cookCount))
        }
        if let kcal = recipe.caloriesPerServing, kcal > 0 {
            parts.append(String.localizedStringWithFormat(L("%lld kcal / porcję"), Int(kcal)))
        }
        if parts.isEmpty {
            parts.append(String.localizedStringWithFormat(L("%lld porcje"), recipe.servings))
        }
        return parts.joined(separator: " · ")
    }
}
