import OSLog
import SwiftUI

/// Full-screen "Porady od Oli". Opens from the OlaInsightsHero on
/// Today. Two segments:
///
/// 1. **Dziś** — Ola's cached summary + every tip (vertical stack,
///    not the tight Today carousel), her "Następny krok" CTA and the
///    rotating ciekawostka-dnia at the bottom.
/// 2. **Ciekawostki** — full browsable fact catalogue with category
///    chips and tap-to-expand rows.
///
/// All UI labels go through `String(localized:)`; fact bodies stay in
/// Polish source language this pass and are translated in a follow-up.
@MainActor
struct OlaTipsView: View {
    private static let logger = Logger(subsystem: "app.mealgram", category: "OlaTipsView")

    let recommendations: Recommendations?
    let lastUpdated: Date?
    let selector: DailyFactSelector
    let onDismiss: () -> Void

    enum Segment: String, CaseIterable, Identifiable {
        case tips
        case facts
        var id: String { rawValue }
    }

    @State private var segment: Segment = .tips
    @State private var categoryFilter: NutritionFact.Category? = nil
    @State private var expandedFactID: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                VStack(spacing: 0) {
                    segmentPicker
                    Group {
                        if segment == .tips {
                            tipsTab
                        } else {
                            factsTab
                        }
                    }
                }
            }
            .navigationTitle(Text("Porady od Oli"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Zamknij"), action: onDismiss)
                }
            }
        }
    }

    // MARK: - Segment picker

    private var segmentPicker: some View {
        Picker("", selection: $segment) {
            Text(String(localized: "Dziś")).tag(Segment.tips)
            Text(String(localized: "Ciekawostki")).tag(Segment.facts)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, Tokens.Space.sm)
        .padding(.bottom, Tokens.Space.md)
    }

    // MARK: - Tips tab

    @ViewBuilder
    private var tipsTab: some View {
        if let recs = recommendations {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    summaryHero(recs: recs)
                    if !recs.warnings.isEmpty {
                        warningsBlock(recs.warnings)
                    }
                    tipsList(recs.tips)
                    if !recs.nextSteps.isEmpty {
                        nextStepCard(recs.nextSteps)
                    }
                    factOfTheDayBlock
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, Tokens.Space.xxl)
            }
        } else {
            emptyRecommendationsState
        }
    }

    private func summaryHero(recs: Recommendations) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
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
                    Text(String(localized: "Twój asystent AI"))
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    if let lastUpdated {
                        Text(
                            String(localized: "Aktualne · ")
                            + lastUpdated.formatted(.relative(presentation: .named))
                        )
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    } else {
                        Text(String(localized: "Twoje spersonalizowane porady"))
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                Spacer(minLength: 0)
            }
            Text(recs.summary)
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .fill(Tokens.Palette.surface)
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
            .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
        )
        .mealgramShadow(Tokens.Shadow.card)
    }

    private func warningsBlock(_ warnings: [String]) -> some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(Array(warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: Tokens.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(warning)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Tokens.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.warning.opacity(0.15))
                )
            }
        }
    }

    private func tipsList(_ tips: [RecommendationTip]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            sectionTitle(String(localized: "Wskazówki na dziś"))
            VStack(spacing: Tokens.Space.md) {
                ForEach(tips) { tip in
                    tipCard(tip)
                }
            }
        }
    }

    private func tipCard(_ tip: RecommendationTip) -> some View {
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
                Text(tip.title)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(tip.description)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink.opacity(0.85))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .mealgramShadow(Tokens.Shadow.card)
    }

    private func nextStepCard(_ next: String) -> some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 40, height: 40)
                    .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 8, y: 3)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "NASTĘPNY KROK"))
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(next)
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
        )
    }

    @ViewBuilder
    private var factOfTheDayBlock: some View {
        if let fact = selector.factForToday() {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                sectionTitle(String(localized: "Ciekawostka dnia"))
                FactCard(fact: fact, highlighted: true)
            }
        }
    }

    private var emptyRecommendationsState: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(String(localized: "Ola jeszcze nie ma porad"))
                .font(Tokens.Font.title3)
                .foregroundStyle(Tokens.Palette.ink)
            Text(String(localized: "Zaloguj kilka posiłków, a wrócimy z gotowymi wskazówkami."))
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
            if let fact = selector.factForToday() {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    sectionTitle(String(localized: "Ciekawostka dnia"))
                    FactCard(fact: fact, highlighted: true)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.lg)
            }
            Spacer()
        }
        .padding(.top, Tokens.Space.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Facts tab

    private var factsTab: some View {
        VStack(spacing: 0) {
            categoryFilterStrip
            ScrollView {
                LazyVStack(spacing: Tokens.Space.md) {
                    ForEach(filteredFacts) { fact in
                        factRow(fact)
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.xxl)
            }
        }
    }

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                filterChip(label: String(localized: "Wszystkie"), isSelected: categoryFilter == nil) {
                    categoryFilter = nil
                    expandedFactID = nil
                }
                ForEach(NutritionFact.Category.allCases) { category in
                    let label = FactCard.localizedCategory(category)
                    filterChip(
                        label: label,
                        isSelected: categoryFilter == category
                    ) {
                        categoryFilter = (categoryFilter == category) ? nil : category
                        expandedFactID = nil
                    }
                }
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.vertical, 2)
        }
    }

    private func filterChip(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptics.light()
            action()
        }) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isSelected ? .white : Tokens.Palette.ink)
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? Tokens.Palette.primary : Tokens.Palette.surface)
                )
                .overlay(
                    Capsule().strokeBorder(
                        isSelected ? Color.clear : Tokens.Palette.separator,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var filteredFacts: [NutritionFact] {
        guard let categoryFilter else { return NutritionFactCatalog.all }
        return NutritionFactCatalog.all.filter { $0.category == categoryFilter }
    }

    private func factRow(_ fact: NutritionFact) -> some View {
        let isExpanded = expandedFactID == fact.id
        return Button {
            withAnimation(Tokens.Motion.gentle) {
                expandedFactID = isExpanded ? nil : fact.id
            }
            Haptics.light()
        } label: {
            if isExpanded {
                FactCard(fact: fact, highlighted: false)
            } else {
                collapsedRow(fact)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }

    private func collapsedRow(_ fact: NutritionFact) -> some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.surfaceMuted)
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
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .strokeBorder(Tokens.Palette.separator, lineWidth: 1)
        )
    }

    // MARK: - Shared

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(Tokens.Font.headline)
            .foregroundStyle(Tokens.Palette.ink)
            .padding(.horizontal, 2)
    }
}
