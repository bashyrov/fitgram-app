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
            Image(systemName: symbol)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(Tokens.Mono.hi)
                .frame(width: 88, height: 88)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Mono.Radius.card, style: .continuous)
                        .fill(Tokens.Mono.hero)
                )
                .accessibilityHidden(true)

            VStack(spacing: Tokens.Space.sm) {
                Text(title)
                    .font(Tokens.Font.monoDisplay(24))
                    .textCase(.uppercase)
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
        message: "Add your first meal by photo, voice or from our database.",
        action: .init(title: "Add meal", perform: {})
    )
    .background(Tokens.Palette.background)
}
