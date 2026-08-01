import SwiftUI

/// Brief celebratory bubble shown after the save path unlocks something.
/// Tap to dismiss; auto-dismisses after a few seconds so it never blocks
/// the user.
struct AchievementUnlockBanner: View {
    let definition: AchievementDefinition
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(spacing: Tokens.Space.md) {
                icon
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .heavy))
                        Text("Nowa odznaka")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                    }
                    .foregroundStyle(Tokens.Palette.warning)
                    .textCase(.uppercase)

                    Text(definition.title)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(definition.summary)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Palette.inkSubtle)
            }
            .padding(Tokens.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.86))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white.opacity(0.42), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.warning.opacity(0.75),
                                Tokens.Palette.primary.opacity(0.55),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .padding(.horizontal, Tokens.Space.lg)
            }
            .shadow(color: Tokens.Palette.primary.opacity(0.18), radius: 24, y: 12)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Tokens.Space.screenPadding)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
    }

    private var icon: some View {
        AchievementMedallion(definition: definition, isEarned: true, size: 58, showsLock: false)
            .shadow(color: Tokens.Palette.warning.opacity(0.28), radius: 14, y: 7)
    }
}
