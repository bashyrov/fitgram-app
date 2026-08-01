import SwiftUI

struct AIQuotaBadge: View {
    let remaining: Int?

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Capsule().fill(tint.opacity(0.13)))
            .overlay {
                Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var label: String {
        guard let remaining else { return "∞" }
        return String.localizedStringWithFormat(L("%lld left"), remaining)
    }

    private var accessibilityLabel: String {
        guard let remaining else { return L("Unlimited AI requests") }
        return String.localizedStringWithFormat(L("%lld AI requests left today"), remaining)
    }

    private var tint: Color {
        guard let remaining else { return Tokens.Palette.primary }
        return remaining == 0 ? Tokens.Palette.error : Tokens.Palette.primary
    }
}
