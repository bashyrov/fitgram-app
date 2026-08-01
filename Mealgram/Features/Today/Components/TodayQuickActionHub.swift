import SwiftUI

struct TodayQuickActionHub: View {
    let canUseOlaAdvice: Bool
    let onOpenAddOptions: () -> Void
    let onOpenScanner: () -> Void
    let onOpenOla: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.xs) {
            quickActionTile(
                title: L("Dodaj"),
                subtitle: L("posiłek"),
                symbol: "plus",
                tint: Tokens.Palette.primary,
                action: onOpenAddOptions
            )
            quickActionTile(
                title: L("Skan"),
                subtitle: L("kamera"),
                symbol: "camera.fill",
                tint: Tokens.Palette.accent,
                action: onOpenScanner
            )
            quickActionTile(
                title: L("Ola"),
                subtitle: canUseOlaAdvice ? L("porady") : L("PRO"),
                symbol: canUseOlaAdvice ? "sparkles" : "lock.fill",
                tint: Tokens.Palette.warning,
                action: onOpenOla
            )
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.62), lineWidth: 0.7)
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.08), radius: 18, y: 9)
    }

    private func quickActionTile(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(tint.opacity(0.14)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    Text(subtitle)
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(0.35)
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.62)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .frame(height: 74)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Tokens.Palette.surfaceMuted.opacity(0.58))
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
