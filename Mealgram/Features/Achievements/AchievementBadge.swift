import SwiftUI

/// Square badge used in the Profile grid. Earned badges show full colour;
/// locked badges show a muted treatment + lock glyph so the user knows
/// what's still available.
struct AchievementBadge: View {
    let definition: AchievementDefinition
    let isEarned: Bool
    let earnedAt: Date?

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(isEarned ? Tokens.Palette.primarySoft : Tokens.Palette.surfaceMuted)
                    .frame(width: 64, height: 64)
                Image(systemName: definition.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(isEarned ? Tokens.Palette.primary : Tokens.Palette.inkSubtle)
                if !isEarned {
                    Circle()
                        .fill(Color.black.opacity(0.18))
                        .frame(width: 64, height: 64)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            Text(definition.title)
                .font(Tokens.Font.footnote)
                .foregroundStyle(isEarned ? Tokens.Palette.ink : Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .accessibilityElement()
        .accessibilityLabel(Text(definition.title))
        .accessibilityValue(Text(isEarned ? "Zdobyte" : "Zablokowane"))
        .accessibilityHint(Text(definition.summary))
    }
}
