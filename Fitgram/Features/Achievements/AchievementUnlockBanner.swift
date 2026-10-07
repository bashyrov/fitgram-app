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
                            .font(Tokens.Font.manrope(11, weight: 800))
                    }
                    .foregroundStyle(Tokens.Mono.hi)
                    .textCase(.uppercase)

                    Text(definition.title)
                        .font(Tokens.Font.archivo(size: 18, weight: 800, width: 112))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text(definition.summary)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
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
    }
}
