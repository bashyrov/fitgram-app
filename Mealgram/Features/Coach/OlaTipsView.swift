import OSLog
import SwiftUI

/// Full-screen "Porady od Oli". This screen is intentionally coach-only:
/// educational facts live in `FactsLibraryView`.
@MainActor
struct OlaTipsView: View {
    private static let logger = Logger(subsystem: "app.mealgram", category: "OlaTipsView")

    let recommendations: Recommendations?
    let lastUpdated: Date?
    let onDismiss: () -> Void

    @State private var selectedCategory: OlaAdviceCategory = .today
    @State private var helpfulTipIDs: Set<String> = []
    @State private var notHelpfulTipIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ZStack {
                olaBackground
                tipsTab
            }
            .navigationTitle(Text("Porady od Oli"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Close"), action: onDismiss)
                }
            }
        }
    }

    private var olaBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.48))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: 150, y: -220)
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.34))
                .frame(width: 310, height: 310)
                .blur(radius: 108)
                .offset(x: -150, y: -40)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.10))
                .frame(width: 250, height: 250)
                .blur(radius: 100)
                .offset(x: 90, y: 330)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var tipsTab: some View {
        if let recs = recommendations {
            ScrollView {
                VStack(alignment: .leading, spacing: Tokens.Space.lg) {
                    OlaLivingHero(recommendations: recs, lastUpdated: lastUpdated)
                    categoryRail
                    selectedCategoryContent(recs)
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, Tokens.Space.md)
                .padding(.bottom, Tokens.Space.xxl)
            }
        } else {
            emptyRecommendationsState
        }
    }

    private var categoryRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Tokens.Space.sm) {
                ForEach(OlaAdviceCategory.allCases) { category in
                    Button {
                        withAnimation(Tokens.Motion.gentle) {
                            selectedCategory = category
                        }
                        Haptics.light()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: category.symbol)
                                .font(.system(size: 12, weight: .bold))
                            Text(category.title)
                                .font(Tokens.Font.caption.weight(.bold))
                        }
                        .foregroundStyle(selectedCategory == category ? .white : Tokens.Palette.ink)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(
                                    selectedCategory == category ? category.tint : Tokens.Palette.surface.opacity(0.84))
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedCategory == category ? .clear : .white.opacity(0.36), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func selectedCategoryContent(_ recs: Recommendations) -> some View {
        switch selectedCategory {
        case .today:
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                if !recs.warnings.isEmpty {
                    OlaWarningsBlock(warnings: recs.warnings)
                }
                adviceList(title: L("Wskazówki na dziś"), tips: recs.tips)
            }
        case .protein, .calories, .habits:
            adviceList(title: selectedCategory.title, tips: tips(for: selectedCategory, in: recs))
        case .memory:
            memoryPanel(recs)
        case .history:
            historyPanel(recs)
        }
    }

    private func adviceList(title: String, tips: [RecommendationTip]) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text(title)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, 2)
            if tips.isEmpty {
                emptyCategoryCard
            } else {
                VStack(spacing: Tokens.Space.sm) {
                    ForEach(tips) { tip in
                        OlaAdviceCard(
                            tip: tip,
                            isHelpful: helpfulTipIDs.contains(reactionID(for: tip)),
                            isNotHelpful: notHelpfulTipIDs.contains(reactionID(for: tip)),
                            onHelpful: { mark(tip, helpful: true) },
                            onNotHelpful: { mark(tip, helpful: false) }
                        )
                    }
                }
            }
        }
    }

    private var emptyCategoryCard: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Palette.success)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Tokens.Palette.success.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text("Tu jest spokojnie")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text("Ola nie widzi teraz nic pilnego w tej kategorii.")
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
    }

    private func memoryPanel(_ recs: Recommendations) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Pamięć Oli")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.sm) {
                OlaMemoryRow(
                    symbol: "target",
                    title: "Twój plan",
                    value: recs.nextSteps.isEmpty ? recs.summary : recs.nextSteps,
                    tint: Tokens.Palette.primary
                )
                OlaMemoryRow(
                    symbol: "heart.text.square.fill",
                    title: "Styl rozmowy",
                    value: "Krótko, konkretnie i bez presji. Ola podpowiada następny mały ruch.",
                    tint: Tokens.Palette.accent
                )
                OlaMemoryRow(
                    symbol: "clock.arrow.circlepath",
                    title: "Ostatnia aktualizacja",
                    value: lastUpdated?.formatted(date: .abbreviated, time: .shortened) ?? L("Po pierwszych posiłkach"),
                    tint: Tokens.Palette.warning
                )
            }
        }
    }

    private func historyPanel(_ recs: Recommendations) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Historia porad")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.sm) {
                ForEach(Array(recs.tips.prefix(8).enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: Tokens.Space.md) {
                        Text(tip.icon)
                            .font(.system(size: 22))
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(Tokens.Palette.primarySoft))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(tip.title)
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(index == 0 ? L("Najnowsza rada") : L("Wróć do tej wskazówki później"))
                                .font(Tokens.Font.caption)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(Tokens.Space.md)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Tokens.Palette.surface.opacity(0.82))
                    )
                }
            }
        }
    }

    private func tips(for category: OlaAdviceCategory, in recs: Recommendations) -> [RecommendationTip] {
        let keywords = category.keywords
        guard !keywords.isEmpty else { return recs.tips }
        let matched = recs.tips.filter { tip in
            let haystack = "\(tip.title) \(tip.description)".lowercased()
            return keywords.contains { haystack.localizedCaseInsensitiveContains($0) }
        }
        return matched.isEmpty ? Array(recs.tips.prefix(2)) : matched
    }

    private func mark(_ tip: RecommendationTip, helpful: Bool) {
        let id = reactionID(for: tip)
        withAnimation(Tokens.Motion.gentle) {
            if helpful {
                helpfulTipIDs.insert(id)
                notHelpfulTipIDs.remove(id)
            } else {
                notHelpfulTipIDs.insert(id)
                helpfulTipIDs.remove(id)
            }
        }
        Haptics.light()
    }

    private func reactionID(for tip: RecommendationTip) -> String {
        "\(tip.title)|\(tip.description)"
    }

    private var emptyRecommendationsState: some View {
        VStack(spacing: Tokens.Space.md) {
            Image(systemName: "sparkles")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(L("Ola jeszcze nie ma porad"))
                .font(Tokens.Font.title3)
                .foregroundStyle(Tokens.Palette.ink)
            Text(L("Zaloguj kilka posiłków, a wrócimy z gotowymi wskazówkami."))
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xl)
            Spacer()
        }
        .padding(.top, Tokens.Space.xxxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
