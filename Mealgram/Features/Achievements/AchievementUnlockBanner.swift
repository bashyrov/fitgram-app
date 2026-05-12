import SwiftUI

/// Brief celebratory bubble shown after the save path unlocks something.
/// Tap to dismiss; auto-dismisses after a few seconds so it never blocks
/// the user.
struct AchievementUnlockBanner: View {
    let definition: AchievementDefinition
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 44, height: 44)
                Image(systemName: definition.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Odznaka!")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(definition.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(definition.summary)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .stroke(Tokens.Palette.primary.opacity(0.4), lineWidth: 1)
        )
        .mealgramShadow(Tokens.Shadow.float)
        .padding(.horizontal, Tokens.Space.screenPadding)
        .onTapGesture(perform: onDismiss)
        .task {
            try? await Task.sleep(for: .seconds(4))
            onDismiss()
        }
    }
}
