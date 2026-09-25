import SwiftUI

struct PaywallComparisonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack {
                Text("Free vs Pro")
                    .font(Tokens.Font.headline)
                    .foregroundStyle(Tokens.Palette.ink)
                Spacer()
                Text("7 dni testu")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundStyle(Tokens.Palette.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Tokens.Palette.primarySoft.opacity(0.78)))
            }
            VStack(spacing: 8) {
                comparisonRow(symbol: "wand.and.stars", title: "AI dziennie", free: "3", pro: "Duże limity")
                comparisonRow(symbol: "arrow.clockwise", title: "Odśwież AI", free: "3 / dzień", pro: "Duże limity")
                comparisonRow(symbol: "leaf.fill", title: "Produkty z AI", free: "2 / dzień", pro: "Duże limity")
                comparisonRow(symbol: "sparkles", title: "Porady Oli", free: "Nie", pro: "Pełny dostęp")
                comparisonRow(symbol: "book.closed.fill", title: "Przepisy", free: "5", pro: "Duże limity")
            }
            .padding(Tokens.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.78))
            )
        }
    }

    private func comparisonRow(
        symbol: String,
        title: LocalizedStringKey,
        free: LocalizedStringKey,
        pro: LocalizedStringKey
    ) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.Palette.primarySoft.opacity(0.62)))
            Text(title)
                .font(Tokens.Font.footnote.weight(.semibold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .frame(width: 86, alignment: .trailing)
            Text(pro)
                .font(Tokens.Font.caption.weight(.bold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 92, alignment: .trailing)
        }
        .padding(.horizontal, Tokens.Space.sm)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Tokens.Palette.surfaceMuted.opacity(0.46))
        )
    }
}

struct PaywallTrustSection: View {
    var body: some View {
        HStack(spacing: Tokens.Space.sm) {
            trustPill(symbol: "lock.shield.fill", text: "Apple Pay")
            trustPill(symbol: "arrow.uturn.backward.circle.fill", text: "Anuluj kiedy chcesz")
            trustPill(symbol: "checkmark.seal.fill", text: "7 dni testu")
        }
    }

    private func trustPill(symbol: String, text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(Tokens.Font.caption2.weight(.bold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Tokens.Palette.inkMuted)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Capsule().fill(Tokens.Palette.surfaceMuted.opacity(0.72)))
    }
}

struct PaywallErrorCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Tokens.Palette.onPrimary)
                .frame(width: 42, height: 42)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Tokens.Palette.warning, Tokens.Palette.primary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
            VStack(alignment: .leading, spacing: 4) {
                Text("Płatność chwilowo nie odpowiada")
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(message)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Tokens.Palette.surface.opacity(0.80))
        )
        .shadow(color: Tokens.Palette.warning.opacity(0.08), radius: 10, y: 5)
    }
}
