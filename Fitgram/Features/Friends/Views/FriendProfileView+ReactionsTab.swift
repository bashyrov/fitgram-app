import SwiftUI

/// "Reactions" tab — three large gradient cards mapping the three positive
/// reaction intents. Each card fires `service.sendPositiveReaction` and
/// shows a toast on success.
extension FriendProfileView {
    @ViewBuilder
    func reactionsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        VStack(spacing: 0) {
            reactionCard(
                intent: .encourage,
                title: L("Zachęć"),
                subtitle: L("Send a sign you're rooting for them today."),
                symbol: "hand.thumbsup.fill",
                tint: Tokens.Palette.primary
            )
            MonoRowDivider()
            reactionCard(
                intent: .celebrate,
                title: L("Pogratuluj"),
                subtitle: L("Świętuj postęp Twojego znajomego."),
                symbol: "party.popper.fill",
                tint: Tokens.Palette.accent
            )
            MonoRowDivider()
            reactionCard(
                intent: .congratulate,
                title: L("Brawo"),
                subtitle: L("Honor the streak and persistence."),
                symbol: "rosette",
                tint: Tokens.Palette.warning
            )
        }
        .monoRowsCard()
    }

    func reactionCard(
        intent: PositiveReactionIntent,
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color
    ) -> some View {
        Button {
            Task { await send(intent: intent) }
        } label: {
            MonoRow(icon: symbol, iconStyle: .dark, title: title, sub: subtitle) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
