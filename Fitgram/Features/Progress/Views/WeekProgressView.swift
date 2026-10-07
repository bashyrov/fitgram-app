import Charts
import SwiftUI

/// 7-day calorie history. Bar chart of daily totals with a dashed target
/// line, summary stats card, per-day list breakdown. Uses Swift Charts
/// (iOS 16+) so we get accessibility-labelled bars for free.
struct WeekProgressView: View {
    let userRemoteID: String
    @Bindable var state: ProgressState
    /// "Itogi tygodnia od Oli" entry — Premium feature raised from the
    /// Week tab. Optional so tests can omit it.
    var onOpenWeeklyDebrief: (() -> Void)?

    /// Pulls the locale set by `LocalizationStore` via `.environment(\.locale, …)`
    /// so chart axis labels render in the in-app language, not the system one.
    @Environment(\.locale) var locale
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue

    var body: some View {
        ZStack {
            progressBackground
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    weekHeader
                    Color.clear.frame(height: 14)
                    weeklyHero
                    chartSectionHeader
                    chartCard
                    Color.clear.frame(height: 10)
                    metricsGrid
                    weekSection("02", L("Makro"))
                    macroCard
                    breakdownSectionHeader
                    breakdownCard
                    if let onOpenWeeklyDebrief {
                        weekSection("04", TL(pl: "Coach", en: "Coach", uk: "Коуч", ru: "Коуч", es: "Coach"))
                        coachRows(onOpen: onOpenWeeklyDebrief)
                    }
                    if !hasWeekEntries {
                        Color.clear.frame(height: 20)
                        emptyWeekCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.bottom, 20)
                .id(accentRaw)
            }
            .refreshable { await state.refresh(for: userRemoteID) }
        }
        .task { await state.refresh(for: userRemoteID) }
    }
}
