import SwiftUI

struct AddMealFlowModeCard: View {
    let symbol: String
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MonoIconBox(systemName: symbol, style: .outline, size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Tokens.Font.archivo(size: 16, weight: 800, width: 115))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(14)
        .monoCard(radius: 22, padding: nil)
    }
}
