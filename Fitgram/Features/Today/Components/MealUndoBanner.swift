import SwiftUI

/// Snackbar shown after a meal delete. Five-second window with a single
/// "Undo" action; tapping it re-saves the meal through the normal
/// MealSaving pipeline so streak/achievements re-fire naturally.
struct MealUndoBanner: View {
    let snapshot: MealEntrySnapshot
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            Image(systemName: "trash")
                .foregroundStyle(Tokens.Palette.warning)
            VStack(alignment: .leading, spacing: 2) {
                Text("Posiłek usunięty")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(.white)
                Text(summary)
                    .font(Tokens.Font.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button {
                Haptics.light()
                onUndo()
            } label: {
                Text("Undo")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, Tokens.Space.md)
                    .padding(.vertical, Tokens.Space.xs)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(.plain)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .accessibilityLabel(Text("Close"))
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.ink)
        )
        .padding(.horizontal, Tokens.Space.screenPadding)
        .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 4)
    }

    private var summary: String {
        guard let first = snapshot.items.first?.name else {
            return L("Wpis bez nazwy")
        }
        if snapshot.items.count > 1 {
            let format = L("%@ i %lld więcej")
            return String.localizedStringWithFormat(format, first, snapshot.items.count - 1)
        }
        return first
    }
}
