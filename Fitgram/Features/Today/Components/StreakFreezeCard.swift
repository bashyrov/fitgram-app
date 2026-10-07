import SwiftUI

/// Shown when the user has a streak going, hasn't logged anything today,
/// and still has freezes left. One tap consumes a freeze so the streak
/// survives the day even without a meal entry.
struct StreakFreezeCard: View {
    let streakLength: Int
    let freezesAvailable: Int
    let onUse: () -> Void

    /// Design D: a single row (outline icon, title, muted line, dark pill). The Today
    /// screen places it at the top of the shared "Na dziś" rows card.
    var body: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "snowflake", style: .outline, size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text(String.localizedStringWithFormat(L("Seria %lld dni czeka"), streakLength))
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(
                    String.localizedStringWithFormat(
                        L("Użyj freeze (zostało %lld), żeby utrzymać serię bez wpisu."),
                        freezesAvailable
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(action: onUse) {
                Text(L("Użyj freeze"))
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .background(Capsule().fill(Tokens.Mono.hero))
            }
            .buttonStyle(PressableButtonStyle())
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
