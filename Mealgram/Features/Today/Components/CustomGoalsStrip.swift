import SwiftUI

/// Horizontal carousel of active custom goals on Today. Self-contained
/// — pulls from GoalsService on appear and after each meal save (driven
/// by the NotificationCenter `mealSaved` post that the rest of Today
/// already listens to).
///
/// Hidden when the user has zero active goals so the screen stays calm.
struct CustomGoalsStrip: View {
    let goalsService: GoalsService

    @State private var goals: [CustomGoal] = []

    var body: some View {
        Group {
            if goals.isEmpty {
                EmptyView()
            } else {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    Text("Twoje cele")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .padding(.horizontal, Tokens.Space.screenPadding)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Tokens.Space.sm) {
                            ForEach(goals) { goal in
                                CustomGoalMiniCard(
                                    goal: goal,
                                    progress: (try? goalsService.progress(for: goal)) ?? 0
                                )
                            }
                        }
                        .padding(.horizontal, Tokens.Space.screenPadding)
                    }
                }
            }
        }
        .task { reload() }
    }

    private func reload() {
        goals = ((try? goalsService.activeGoals()) ?? []).filter { $0.isActive }
    }
}

private struct CustomGoalMiniCard: View {
    let goal: CustomGoal
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(Tokens.Palette.primary)
                Text(goal.name)
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
            }
            ProgressView(value: progress)
                .tint(Tokens.Palette.primary)
            Text("\(Int(progress * 100))% · do \(goal.endDate.formatted(.dateTime.day().month()))")
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
        }
        .padding(Tokens.Space.md)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
                .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        )
    }
}
