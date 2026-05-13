import SwiftUI

/// Hero card — calories so far today, remaining, and a soft progress ring.
struct CalorieProgressCard: View {
    let consumed: Double
    let goal: Int
    let progress: Double
    var onTapGoal: (() -> Void)?

    private var goalHit: Bool {
        progress >= 1.0
    }

    private var ringColor: Color {
        if progress >= 1.2 { return Tokens.Palette.error }
        if goalHit { return Tokens.Palette.warning }
        return Tokens.Palette.primary
    }

    var body: some View {
        Card(elevation: Tokens.Shadow.float) {
            HStack(alignment: .center, spacing: Tokens.Space.lg) {
                ZStack {
                    Circle()
                        .stroke(Tokens.Palette.surfaceMuted, lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1.0, progress)))
                        .stroke(
                            ringColor,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(Tokens.Motion.gentle, value: progress)
                    VStack(spacing: 0) {
                        Text("\(Int(consumed))")
                            .font(Tokens.Font.counter)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(goalHit ? "✓ \(goal) kcal" : "/ \(goal) kcal")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(goalHit ? Tokens.Palette.warning : Tokens.Palette.inkMuted)
                    }
                }
                .frame(width: 156, height: 156)

                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    summaryRow(label: "Spożyte", value: "\(Int(consumed)) kcal", color: Tokens.Palette.primary)
                    if let onTapGoal {
                        Button {
                            onTapGoal()
                        } label: {
                            summaryRow(
                                label: "Cel — stuknij, aby zmienić",
                                value: "\(goal) kcal",
                                color: Tokens.Palette.primary
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        summaryRow(label: "Cel", value: "\(goal) kcal", color: Tokens.Palette.inkMuted)
                    }
                    summaryRow(
                        label: "Pozostało",
                        value: "\(max(0, goal - Int(consumed))) kcal",
                        color: Tokens.Palette.ink
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func summaryRow(
        label: LocalizedStringKey,
        value: LocalizedStringKey,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Text(value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(color)
        }
    }
}
