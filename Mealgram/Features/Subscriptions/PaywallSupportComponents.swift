import SwiftUI

struct PaywallComparisonSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            Text("Free vs Pro")
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            VStack(spacing: Tokens.Space.xs) {
                comparisonRow(title: "AI dziennie", free: "3", pro: "Bez limitu")
                comparisonRow(title: "Odśwież AI", free: "3 / dzień", pro: "Bez limitu")
                comparisonRow(title: "Produkty z AI", free: "2 / dzień", pro: "Bez limitu")
                comparisonRow(title: "Porady Oli", free: "Zablokowane", pro: "Pełny dostęp")
                comparisonRow(title: "Przepisy", free: "5", pro: "Bez limitu")
            }
            .padding(Tokens.Space.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84)))
        }
    }

    private func comparisonRow(
        title: LocalizedStringKey, free: LocalizedStringKey, pro: LocalizedStringKey
    ) -> some View {
        HStack(spacing: Tokens.Space.sm) {
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
        .padding(.vertical, 6)
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
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Tokens.Palette.warning)
                .frame(width: 38, height: 38)
                .background(Circle().fill(Tokens.Palette.warning.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Nie udało się dokończyć akcji")
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
                .fill(Tokens.Palette.warning.opacity(0.11))
        )
    }
}
