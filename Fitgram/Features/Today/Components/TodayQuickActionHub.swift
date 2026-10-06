import SwiftUI

/// Design D quick actions: one wide accent "Dodaj posiłek" tile plus two
/// dark tiles (scanner, Ola). Same callbacks as before.
struct TodayQuickActionHub: View {
    let canUseOlaAdvice: Bool
    let onOpenAddOptions: () -> Void
    let onOpenScanner: () -> Void
    let onOpenOla: () -> Void

    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            Button {
                Haptics.light()
                onOpenAddOptions()
            } label: {
                VStack(alignment: .leading) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(L("Dodaj"))
                            .font(Tokens.Font.monoDisplay(22))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(L("posiłek"))
                            .font(Tokens.Font.manrope(12, weight: 800))
                            .foregroundStyle(Tokens.Mono.onAccentSub)
                            .lineLimit(1)
                    }
                }
                .foregroundStyle(Tokens.Mono.onAccent)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: 88, maxHeight: 88, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                        .fill(Tokens.Mono.accent)
                )
            }
            .buttonStyle(PressableButtonStyle())

            darkTile(title: L("Skan"), subtitle: L("kamera"), symbol: "camera", action: onOpenScanner)
            darkTile(
                title: L("Ola"),
                subtitle: canUseOlaAdvice ? L("porady") : L("PRO"),
                symbol: canUseOlaAdvice ? "sparkles" : "lock.fill",
                highlightSubtitle: !canUseOlaAdvice,
                action: onOpenOla
            )
        }
    }

    private func darkTile(
        title: String,
        subtitle: String,
        symbol: String,
        highlightSubtitle: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            VStack(alignment: .leading) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                Spacer(minLength: 0)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Tokens.Font.archivo(size: 15, weight: 800, width: 115))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(11, weight: 800))
                        .foregroundStyle(highlightSubtitle ? Tokens.Mono.hi : Tokens.Mono.heroMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(Tokens.Mono.onHero)
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(width: 84, height: 88, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text("\(title), \(subtitle)"))
    }
}
