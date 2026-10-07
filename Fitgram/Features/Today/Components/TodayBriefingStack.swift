import SwiftUI

// swiftlint:disable:next type_body_length
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

    /// When true the rows render without their own card so the caller can
    /// merge them into a shared rows card (mockup "02 Na dziś").
    var isEmbedded = false

    private var hasContent: Bool {
        fact != nil || recommendations != nil || coachInsight != nil
            || isOlaLocked || upcomingEvent != nil || suggestedRecipe != nil
    }

    var body: some View {
        if hasContent {
            if isEmbedded {
                rowsStack
            } else {
                rowsStack
                    .monoRowsCard()
            }
        }
    }

    // Design D: no inner header — the Today screen provides numbered section headers.
    private var rowsStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            contentRows
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
            rowDivider(if: recommendations != nil || isOlaLocked || fact != nil || coachInsight != nil)
            eventRow(upcomingEvent)
        }
        if let suggestedRecipe, let onCookSuggested {
            rowDivider(
                if: recommendations != nil || isOlaLocked || fact != nil || coachInsight != nil
                    || upcomingEvent != nil
            )
            recipeRow(suggestedRecipe, onCook: { onCookSuggested(suggestedRecipe) })
        }
    }

    // Mockup (free): outline icon, "Porady od Oli" + PRO badge, muted line, chevron.
    private var lockedOlaRow: some View {
        Button(action: onOpenTips) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "sparkles", style: .outline, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(L("Porady od Oli"))
                            .font(Tokens.Font.manrope(15, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                        proBadge
                    }
                    Text(L("Indywidualne wskazówki AI są dostępne w Pro."))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MonoChevron()
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Porady od Oli Pro"))
    }

    private var proBadge: some View {
        Text(L("PRO"))
            .font(Tokens.Font.manrope(10, weight: 900))
            .tracking(0.8)
            .foregroundStyle(Tokens.Mono.hi)
            .padding(.horizontal, 7)
            .frame(height: 20)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
    }

    @ViewBuilder
    private func rowDivider(if isVisible: Bool) -> some View {
        if isVisible {
            MonoRowDivider()
        }
    }

    // Mockup: outline icon, "PORADY OD OLI" label + 16/700 summary, green dot + chevron.
    private func coachPlanRow(_ recommendations: Recommendations) -> some View {
        Button(action: onOpenTips) {
            HStack(alignment: .top, spacing: 12) {
                MonoIconBox(systemName: "sparkles", style: .outline, size: 40)
                VStack(alignment: .leading, spacing: 3) {
                    MonoLabel(text: L("Porady od Oli"))
                    Text(L(recommendations.summary))
                        .font(Tokens.Font.manrope(16, weight: 700))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineSpacing(3)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                recommendationsAccessory
                    .padding(.top, 4)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Otwórz porady od Oli"))
    }

    private var recommendationsAccessory: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if recommendationsUpdatedAt != nil {
                Circle()
                    .fill(Tokens.Palette.success)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel(Text("Zaktualizowano"))
            }
            MonoChevron()
        }
    }

    // Mockup: outline bulb icon, "Ciekawostka dnia" + muted fact line, chevron.
    private func factRow(_ fact: NutritionFact) -> some View {
        Button(action: onOpenTips) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "lightbulb", style: .outline, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Ciekawostka dnia"))
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(fact.title)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                MonoChevron()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("Otwórz Ciekawostki"))
    }

    // Mockup: track icon, 15/800 headline, 13/600 body, dark "action →" pill, dismiss ×.
    private func insightRow(_ insight: CoachInsight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MonoIconBox(systemName: symbol(for: insight.tone), style: .track, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(L(insight.headline))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(L(insight.body))
                    .font(Tokens.Font.manrope(13, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(2)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                if let title = insight.actionTitle, let kind = insight.actionKind {
                    Button {
                        onCoachAction(kind)
                    } label: {
                        HStack(spacing: 6) {
                            Text(L(title))
                                .lineLimit(1)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .heavy))
                        }
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Capsule().fill(Tokens.Mono.hero))
                    }
                    .buttonStyle(PressableButtonStyle())
                    .padding(.top, 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if let onDismissInsight {
                Button {
                    onDismissInsight(insight)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Tokens.Mono.muted)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, -6)
                .padding(.trailing, -6)
                .accessibilityLabel(Text("Ukryj"))
            }
        }
        .padding(16)
    }

    // Mockup: outline icon, "DZISIAJ · ZA 3 DNI" label + event name, dismiss ×.
    private func eventRow(_ upcoming: CulturalEventService.Upcoming) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: upcoming.event.symbol, style: .outline, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                MonoLabel(text: eventBadge(upcoming))
                Text(L(upcoming.event.name))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text(L(upcoming.event.foodNote))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onDismissEvent) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Tokens.Mono.muted)
                    .frame(width: 40, height: 40)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Ukryj"))
        }
        .padding(.leading, 16)
        .padding(.trailing, 10)
        .padding(.vertical, 14)
    }

    private func recipeRow(_ recipe: Recipe, onCook: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "book.closed", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                MonoLabel(text: L("Favorites"))
                Text(recipe.title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Text(recipeSubtitle(recipe))
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onCook) {
                Text(L("Ugotuj"))
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .padding(.horizontal, 14)
                    .frame(height: 36)
                    .background(Capsule().fill(Tokens.Mono.hero))
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel(Text(String.localizedStringWithFormat(L("Ugotuj %@"), recipe.title)))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Tokens.Palette.inkSubtle)
            .padding(.top, 2)
    }

    private func iconPuck(systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                .fill(Tokens.Mono.track)
                .frame(width: 42, height: 42)
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private func iconPuck(text: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                .fill(Tokens.Mono.track)
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
