import SwiftUI

/// Friendly empty-state placeholder. Used when a screen has no data yet
/// (no meals today, empty recipe library, no chat history).
struct EmptyState: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var action: Action?

    struct Action {
        let title: LocalizedStringKey
        let perform: () -> Void
    }

    var body: some View {
        VStack(spacing: Tokens.Space.lg) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 96, height: 96)
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(Tokens.Palette.primary)
            }
            .accessibilityHidden(true)

            VStack(spacing: Tokens.Space.sm) {
                Text(title)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Tokens.Space.lg)

            if let action {
                PrimaryButton(title: action.title, action: action.perform)
                    .padding(.horizontal, Tokens.Space.xl)
                    .padding(.top, Tokens.Space.sm)
            }
        }
        .padding(Tokens.Space.xl)
        .frame(maxWidth: .infinity)
    }
}

#Preview("Empty state") {
    EmptyState(
        symbol: "fork.knife",
        title: "Nic jeszcze dziś",
        message: "Dodaj pierwsze danie zdjęciem, głosem albo z naszej bazy.",
        action: .init(title: "Dodaj posiłek", perform: {})
    )
    .background(Tokens.Palette.background)
}
