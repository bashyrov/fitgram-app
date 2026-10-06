import SwiftUI

enum PortionAdjustmentMode: String, Hashable {
    case overall
    case detailed
}

struct PortionModeSelector: View {
    @Binding var selection: PortionAdjustmentMode
    var totalLabel: String
    var detailLabel: String
    var detailCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.sm) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Palette.primary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
                VStack(alignment: .leading, spacing: 3) {
                    Text(L("Jak zapisać posiłek?"))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Wybierz, czy do dziennika trafi jedno danie, czy składniki osobno."))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: Tokens.Space.sm) {
                modeButton(
                    mode: .overall,
                    symbol: "circle.grid.2x2.fill",
                    title: L("Ogólny"),
                    subtitle: totalLabel,
                    tint: Tokens.Palette.primary
                )
                modeButton(
                    mode: .detailed,
                    symbol: "list.bullet.rectangle.portrait.fill",
                    title: L("Detaliczny"),
                    subtitle: detailLabel,
                    tint: Tokens.Palette.accent
                )
            }

            HStack(spacing: Tokens.Space.xs) {
                Image(systemName: selection == .overall ? "tray.full.fill" : "list.clipboard.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(selection == .overall ? Tokens.Palette.primary : Tokens.Palette.accent)
                Text(statusText)
                    .font(Tokens.Font.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Tokens.Space.sm)
        }
        .padding(Tokens.Space.md)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 0.35))
    }

    private var statusText: String {
        switch selection {
        case .overall:
            return L("Zapiszemy jedną pozycję. AI możesz poprawić nazwą, wagą i makro.")
        case .detailed:
            return String.localizedStringWithFormat(
                L("Zapiszemy %lld składników. Każdy produkt można poprawić osobno."),
                detailCount
            )
        }
    }

    private func modeButton(
        mode: PortionAdjustmentMode,
        symbol: String,
        title: String,
        subtitle: String,
        tint: Color
    ) -> some View {
        let selected = selection == mode
        return Button {
            withAnimation(Tokens.Motion.gentle) {
                selection = mode
            }
            Haptics.selection()
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selected ? .white : tint)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(selected ? tint : tint.opacity(0.14)))
                    Spacer(minLength: 0)
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(selected ? tint : Tokens.Palette.inkSubtle)
                }
                Text(title)
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.caption2)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
            .padding(Tokens.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? tint.opacity(0.14) : Tokens.Palette.surface.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.clear, lineWidth: 0)
            )
        }
        .buttonStyle(.pressable)
    }
}
