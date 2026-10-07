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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                MonoIconBox(systemName: "slider.horizontal.3", style: .track, size: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(L("Jak zapisać posiłek?"))
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Wybierz, czy do dziennika trafi jedno danie, czy składniki osobno."))
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            MonoSegmented(
                selection: $selection,
                options: [
                    (value: PortionAdjustmentMode.overall, title: L("Ogólny")),
                    (value: PortionAdjustmentMode.detailed, title: L("Detaliczny")),
                ]
            )
            .accessibilityHint(Text(selection == .overall ? totalLabel : detailLabel))

            Text(statusText)
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .monoCard(padding: 16)
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
}
