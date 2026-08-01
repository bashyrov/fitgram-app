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

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            progressBackground.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    weeklyHero
                    metricsGrid
                    if let onOpenWeeklyDebrief {
                        WeeklyDebriefShortcut(onTap: onOpenWeeklyDebrief)
                    }
                    chartCard
                    breakdownCard
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
            .refreshable { await state.refresh(for: userRemoteID) }
        }
        .task { await state.refresh(for: userRemoteID) }
    }
}
