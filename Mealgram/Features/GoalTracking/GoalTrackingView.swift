import SwiftUI

/// Full-screen Goal Tracking surface. Big chart + "Wpisz dzisiejszą
/// wagę" CTA. Premium-only — caller is responsible for the gate.
struct GoalTrackingView: View {
    let userRemoteID: String
    @Bindable var state: GoalTrackingState
    let onDismiss: () -> Void
    /// Optional inline tips block — typically the same 3 tips the Today
    /// card surfaces, but rendered with more breathing room here so
    /// the user has the full advice context in one place.
    var tips: [RecommendationTip] = []

    @State private var isAddPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                Tokens.Palette.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: Tokens.Space.lg) {
                        if let snapshot = state.snapshot {
                            if snapshot.isGoalReached {
                                goalReachedPill
                            }
                            summaryCard(snapshot)
                            chartCard(snapshot)
                            if !tips.isEmpty {
                                tipsCard
                            }
                            PrimaryButton(
                                title: "Wpisz dzisiejszą wagę",
                                systemImage: "scalemass.fill",
                                isLoading: state.isSaving
                            ) {
                                isAddPresented = true
                            }
                        } else {
                            emptyCard
                        }
                    }
                    .padding(.horizontal, Tokens.Space.screenPadding)
                    .padding(.vertical, Tokens.Space.lg)
                }
            }
            .navigationTitle(Text("Your goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", action: onDismiss)
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
                .foregroundStyle(.white)
            Text("Goal reached 🎉")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.vertical, Tokens.Space.sm)
        .background(
            Capsule().fill(Tokens.Palette.success)
        )
        .frame(maxWidth: .infinity)
    }

    private func summaryCard(_ snapshot: GoalTrackingService.Snapshot) -> some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Aktualnie")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text(String(format: "%.1f kg", snapshot.currentWeightKg))
                            .font(Tokens.Font.counter)
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Goal")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                        Text(String(format: "%.1f kg", snapshot.targetWeightKg))
                            .font(Tokens.Font.title2)
                            .foregroundStyle(Tokens.Palette.primary)
                    }
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Tokens.Palette.primarySoft)
                        Capsule()
                            .fill(Tokens.Palette.primary)
                            .frame(width: proxy.size.width * CGFloat(snapshot.progress))
                    }
                }
                .frame(height: 10)
                HStack {
                    Text(progressLabel(snapshot))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                    Spacer()
                    Text(daysLabel(snapshot))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
        }
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

    private var tipsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Tokens.Palette.primary)
                    Text("AI Coach tips")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                ForEach(tips) { tip in
                    HStack(alignment: .top, spacing: Tokens.Space.sm) {
                        Text(tip.icon)
                            .font(.system(size: 22))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(LocalizedStringKey(tip.title))
                                .font(Tokens.Font.bodyEmphasized)
                                .foregroundStyle(Tokens.Palette.ink)
                            Text(LocalizedStringKey(tip.description))
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }

    private var emptyCard: some View {
        Card {
            VStack(spacing: Tokens.Space.md) {
                Image(systemName: "target")
                    .font(.system(size: 36))
                    .foregroundStyle(Tokens.Palette.primary)
                Text("Brak aktywnego celu")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    "Select the goal \"Lose weight\" or \"Gain weight\" in Profile → Goals to activate tracking."
                )
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
