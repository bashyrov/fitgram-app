import SwiftUI

/// Compact water-tracking card on Today. 250 ml glass icons fill in as
/// the user logs sips; tap "Dolej" to add another, long-press for "Usuń
/// ostatnie" undo. Daily goal is `WaterService.defaultDailyGoalMilliliters`.
struct WaterCard: View {
    let totalMilliliters: Int
    let goalMilliliters: Int
    let onAddGlass: () -> Void
    let onUndo: () -> Void
    var onEditGoal: (() -> Void)?

    private var glassesConsumed: Double {
        Double(totalMilliliters) / Double(WaterService.glassMilliliters)
    }

    private var goalGlasses: Int {
        max(1, Int((Double(goalMilliliters) / Double(WaterService.glassMilliliters)).rounded()))
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                HStack {
                    Text("Woda")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Spacer()
                    if let onEditGoal {
                        Button {
                            onEditGoal()
                        } label: {
                            Text("\(totalMilliliters) / \(goalMilliliters) ml")
                                .font(Tokens.Font.footnote)
                                .foregroundStyle(Tokens.Palette.primary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Zmień dzienny cel wody"))
                    } else {
                        Text("\(totalMilliliters) / \(goalMilliliters) ml")
                            .font(Tokens.Font.footnote)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                }
                glassRow
                HStack(spacing: Tokens.Space.sm) {
                    Button {
                        onAddGlass()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "drop.fill")
                            Text("Dolej 250 ml")
                                .font(Tokens.Font.footnote.bold())
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, Tokens.Space.md)
                        .padding(.vertical, Tokens.Space.sm)
                        .background(
                            Capsule().fill(Tokens.Palette.primary)
                        )
                    }
                    .buttonStyle(.plain)
                    if totalMilliliters > 0 {
                        Button {
                            onUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Tokens.Palette.inkMuted)
                                .frame(width: 36, height: 36)
                                .background(
                                    Circle().fill(Tokens.Palette.surfaceMuted)
                                )
                        }
                        .accessibilityLabel(Text("Cofnij ostatnią szklankę"))
                    }
                }
            }
        }
    }

    private var glassRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<goalGlasses, id: \.self) { index in
                Image(systemName: glassSymbol(for: index))
                    .font(.system(size: 22))
                    .foregroundStyle(glassColor(for: index))
            }
        }
    }

    private func glassSymbol(for index: Int) -> String {
        Double(index) < glassesConsumed ? "drop.fill" : "drop"
    }

    private func glassColor(for index: Int) -> Color {
        Double(index) < glassesConsumed ? Tokens.Palette.primary : Tokens.Palette.inkSubtle
    }
}
