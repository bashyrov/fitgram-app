import SwiftUI

/// "Free vs Pro" table: header row + hairline-separated feature rows.
struct PaywallComparisonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaywallSectionTitle(title: L("Free vs Pro"))
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
                    MonoLabel(text: L("Free"))
                        .frame(width: columnWidth)
                    MonoLabel(text: L("Pro"))
                        .frame(width: columnWidth)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                comparisonRow(title: "AI dziennie", free: "3", pro: "Duże limity")
                comparisonRow(title: "Odśwież AI", free: "3 / dzień", pro: "Duże limity")
                comparisonRow(title: "Produkty z AI", free: "2 / dzień", pro: "Duże limity")
                comparisonRow(title: "Porady Oli", free: "Nie", pro: "Pełny dostęp")
                comparisonRow(title: "Przepisy", free: "5", pro: "Duże limity")
            }
            .monoRowsCard()
        }
    }

    private let columnWidth: CGFloat = 84

    private func comparisonRow(
        title: LocalizedStringKey,
        free: LocalizedStringKey,
        pro: LocalizedStringKey
    ) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .foregroundStyle(Tokens.Palette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(free)
                .foregroundStyle(Tokens.Mono.muted)
                .multilineTextAlignment(.center)
                .frame(width: columnWidth)
            Text(pro)
                .font(Tokens.Font.manrope(13, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .multilineTextAlignment(.center)
                .frame(width: columnWidth)
        }
        .font(Tokens.Font.manrope(13, weight: 700))
        .lineLimit(2)
        .minimumScaleFactor(0.8)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.line).frame(height: 1)
        }
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
        .background(Capsule().fill(Tokens.Mono.track))
    }
}

struct PaywallErrorCard: View {
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Tokens.Mono.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text("Płatność chwilowo nie odpowiada")
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(message)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monoCard(padding: 16)
    }
}
