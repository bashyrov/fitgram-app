import SwiftUI

/// Shown when the user has a streak going, hasn't logged anything today,
/// and still has freezes left. One tap consumes a freeze so the streak
/// survives the day even without a meal entry.
struct StreakFreezeCard: View {
    let streakLength: Int
    let freezesAvailable: Int
    let onUse: () -> Void

    var body: some View {
        Card(background: Tokens.Palette.surface) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(Tokens.Mono.track)
                        .frame(width: 40, height: 40)
                    Image(systemName: "snowflake")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.ink)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(String.localizedStringWithFormat(L("Seria %lld dni czeka"), streakLength))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        String.localizedStringWithFormat(
                            L("Użyj freeze (zostało %lld), żeby utrzymać serię bez wpisu."),
                            freezesAvailable
                        )
                    )
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
                        .foregroundStyle(Tokens.Palette.ink)
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
    }
}
