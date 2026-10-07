import SwiftUI

/// Full-screen Goal Tracking surface. Big chart + "Wpisz dzisiejszą
/// wagę" CTA. Premium-only — caller is responsible for the gate.
struct GoalTrackingView: View {
    let userRemoteID: String
    @Bindable var state: GoalTrackingState
    let onDismiss: () -> Void
    var onWeightSaved: (() -> Void)?
    /// Optional inline tips block — typically the same 3 tips the Today
    /// card surfaces, but rendered with more breathing room here so
    /// the user has the full advice context in one place.
    var tips: [RecommendationTip] = []

    @State private var isAddPresented = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let snapshot = state.snapshot {
                        if snapshot.isGoalReached {
                            goalReachedPill
                                .padding(.bottom, 10)
                        }
                        summaryCard(snapshot)
                        chartCard(snapshot)
                            .padding(.top, 10)
                        if !tips.isEmpty {
                            MonoSectionHeader(title: L("AI Coach tips"))
                                .padding(.horizontal, 6)
                                .padding(.top, 6)
                                .padding(.bottom, 12)
                            tipsCard
                        }
                    } else {
                        emptyCard
                    }
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .background(Tokens.Palette.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                if state.snapshot != nil {
                    MonoBottomBar {
                        Button {
                            isAddPresented = true
                        } label: {
                            HStack(spacing: 8) {
                                if state.isSaving {
                                    ProgressView()
                                        .tint(Tokens.Mono.onHero)
                                } else {
                                    Image(systemName: "scalemass")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                Text("Wpisz dzisiejszą wagę")
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                        .buttonStyle(MonoButtonStyle(kind: .dark))
                        .disabled(state.isSaving)
                    }
                }
            }
            .monoNavigationTitle(L("Your goal"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MonoNavText(title: L("Close"), action: onDismiss)
                }
            }
            .task { state.refresh(for: userRemoteID) }
            .sheet(isPresented: $isAddPresented) {
                AddGoalWeightSheet(
                    initialWeight: state.snapshot?.currentWeightKg,
                    onCommit: { weight in
                        Task {
                            await state.logTodayWeight(weight, for: userRemoteID)
                            Haptics.success()
                            onWeightSaved?()
                        }
                    },
                    onDismiss: { isAddPresented = false }
                )
            }
        }
    }

    private var goalReachedPill: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Tokens.Mono.onHi)
            Text("Goal reached 🎉")
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Mono.onHi)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            Capsule().fill(Tokens.Mono.goalDone)
        )
        .frame(maxWidth: .infinity)
    }

    /// Mockup hero: "TWÓJ CEL · AI" / day counter, current vs goal (44 pt), 8 pt hi progress bar, "Postęp 34%".
    private func summaryCard(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                MonoLabel(text: L("Twój cel · AI"), onHero: true)
                Spacer(minLength: 8)
                MonoLabel(text: daysLabel(snapshot), onHero: true)
            }
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    MonoLabel(text: L("Aktualnie"), onHero: true)
                    Text(String(format: "%.1f", snapshot.currentWeightKg))
                        .font(Tokens.Font.monoNumber(44))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    MonoLabel(text: L("Goal"), onHero: true)
                    Text(String(format: "%.1f", snapshot.targetWeightKg))
                        .font(Tokens.Font.monoNumber(44))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
            }
            MonoBar(progress: snapshot.progress, color: Tokens.Mono.hi, track: Tokens.Mono.heroLine, height: 8)
            Text(progressLabel(snapshot))
                .font(Tokens.Font.manrope(13, weight: 700))
                .foregroundStyle(Tokens.Mono.heroMuted)
        }
        .monoHero(padding: 20)
    }

    private func progressLabel(_ snapshot: GoalTrackingService.Snapshot) -> String {
        let percent = Int((snapshot.progress * 100).rounded())
        return String.localizedStringWithFormat(L("Progress %lld%%"), percent)
    }

    private func daysLabel(_ snapshot: GoalTrackingService.Snapshot) -> String {
        if let total = snapshot.totalDays, total > 0 {
            return String.localizedStringWithFormat(L("Day %lld of %lld"), snapshot.daysElapsed, total)
        }
        return String.localizedStringWithFormat(L("Day %lld"), snapshot.daysElapsed)
    }

    private func chartCard(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        GoalTrendChart(snapshot: snapshot)
    }

    /// Mockup `rows([row('spark', tip, None, None, 'track'), …])`.
    private var tipsCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(tips.enumerated()), id: \.element.id) { index, tip in
                if index > 0 {
                    MonoRowDivider()
                }
                MonoRow(
                    icon: "sparkles",
                    iconStyle: .track,
                    title: L(tip.title),
                    sub: tip.description.isEmpty ? nil : L(tip.description)
                ) {
                    EmptyView()
                }
            }
        }
        .monoRowsCard()
    }

    private var emptyCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "target", style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Brak aktywnego celu")
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Select the goal \"Lose weight\" or \"Gain weight\" in Profile → Goals to activate tracking."
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .monoCard(padding: 16)
    }
}
