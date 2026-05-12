import SwiftUI

/// Shown when the user has a streak going, hasn't logged anything today,
/// and still has freezes left. One tap consumes a freeze so the streak
/// survives the day even without a meal entry.
struct StreakFreezeCard: View {
    let streakLength: Int
    let freezesAvailable: Int
    let onUse: () -> Void

    var body: some View {
        Card(background: Tokens.Palette.warning.opacity(0.12)) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.warning.opacity(0.25))
                        .frame(width: 40, height: 40)
                    Image(systemName: "snowflake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Seria \(streakLength) dni czeka")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Użyj freeze (zostało \(freezesAvailable)), żeby utrzymać serię bez wpisu.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(action: onUse) {
                        HStack(spacing: 4) {
                            Text("Użyj freeze")
                                .font(Tokens.Font.footnote.bold())
                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Tokens.Palette.warning)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
