import SwiftUI

extension FriendsRootView {
    func heroMetric(value: String, label: String, symbol: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(Tokens.Font.monoNumber(24))
                .foregroundStyle(Tokens.Mono.onHero)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Tokens.Font.caption.weight(.semibold))
                .foregroundStyle(Tokens.Mono.heroMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Mono.heroLine)
        )
    }
}
