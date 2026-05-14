import SwiftUI

/// Editorial hero — full-width charcoal block with a giant serif number
/// and a horizontal progress lozenge. The ring is gone; in its place a
/// magazine-style stat layout that reads at glance: consumed / goal /
/// remaining in three vertical columns.
struct CalorieProgressCard: View {
    let consumed: Double
    let goal: Int
    let progress: Double
    var onTapGoal: (() -> Void)?

    private var goalHit: Bool { progress >= 1.0 }
    private var overShoot: Bool { progress >= 1.2 }
    private var remaining: Int { max(0, goal - Int(consumed)) }

    private var fillColor: Color {
        if overShoot { return Tokens.Palette.error }
        if goalHit { return Tokens.Palette.warning }
        return Tokens.Palette.primary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            heroNumber
            progressTrack
            statsRow
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                    .fill(Tokens.Palette.ink)
                LinearGradient(
                    colors: [
                        Tokens.Palette.primary.opacity(0.18),
                        Tokens.Palette.primary.opacity(0.0),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
            }
        )
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(fillColor)
                    .frame(width: 6, height: 6)
                Text("Dzisiaj")
                    .eyebrowStyle()
                    .foregroundStyle(Tokens.Palette.background.opacity(0.7))
            }
            Spacer()
            Text("\(Int(progress * 100))%")
                .font(.system(size: 13, weight: .semibold, design: .default))
                .foregroundStyle(Tokens.Palette.background.opacity(0.8))
        }
        .padding(.bottom, Tokens.Space.lg)
    }

    private var heroNumber: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(Int(consumed))")
                .font(.system(size: 76, weight: .black, design: .serif))
                .foregroundStyle(Tokens.Palette.background)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("kcal")
                .font(.system(size: 18, weight: .medium, design: .default))
                .foregroundStyle(Tokens.Palette.background.opacity(0.55))
        }
        .padding(.bottom, Tokens.Space.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Spożyte \(Int(consumed)) kilokalorii"))
    }

    private var progressTrack: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Tokens.Palette.background.opacity(0.12))
                .frame(height: 8)
            GeometryReader { geo in
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(8, geo.size.width * CGFloat(min(progress, 1.2))))
            }
            .frame(height: 8)
        }
        .padding(.bottom, Tokens.Space.lg)
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statColumn(label: "Cel", value: "\(goal)", emphasis: false)
                .onTapGesture { onTapGoal?() }
            divider
            statColumn(
                label: goalHit ? "Nadwyżka" : "Pozostało",
                value: goalHit ? "+\(Int(consumed) - goal)" : "\(remaining)",
                emphasis: false
            )
            divider
            statColumn(
                label: "Spożyte",
                value: "\(Int(consumed))",
                emphasis: true
            )
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Tokens.Palette.background.opacity(0.16))
            .frame(width: 1)
            .padding(.vertical, 4)
    }

    private func statColumn(label: LocalizedStringKey, value: String, emphasis: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .eyebrowStyle()
                .foregroundStyle(Tokens.Palette.background.opacity(0.55))
            Text(value)
                .font(.system(size: 22, weight: emphasis ? .heavy : .semibold, design: .serif))
                .foregroundStyle(Tokens.Palette.background)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Tokens.Space.md)
    }
}
