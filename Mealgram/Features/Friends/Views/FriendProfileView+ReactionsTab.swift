import SwiftUI

/// "Reakcje" tab — three large gradient cards mapping the three positive
/// reaction intents. Each card fires `service.sendPositiveReaction` and
/// shows a toast on success.
extension FriendProfileView {
    @ViewBuilder
    func reactionsTab(_ snapshot: FriendProfileSnapshot) -> some View {
        VStack(spacing: Tokens.Space.md) {
            reactionCard(
                intent: .encourage,
                title: "Zachęć",
                subtitle: "Daj sygnał, że trzymasz kciuki za dzisiaj.",
                symbol: "hand.thumbsup.fill",
                tint: Tokens.Palette.primary
            )
            reactionCard(
                intent: .celebrate,
                title: "Pogratuluj",
                subtitle: "Świętuj postęp Twojego znajomego.",
                symbol: "party.popper.fill",
                tint: Tokens.Palette.accent
            )
            reactionCard(
                intent: .congratulate,
                title: "Brawo",
                subtitle: "Doceń serię i wytrwałość.",
                symbol: "rosette",
                tint: Tokens.Palette.warning
            )
        }
    }

    func reactionCard(
        intent: PositiveReactionIntent,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        symbol: String,
        tint: Color
    ) -> some View {
        Button {
            Task { await send(intent: intent) }
        } label: {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: tint.opacity(0.35), radius: 8, y: 3)
                    Image(systemName: symbol)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(subtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tint)
            }
            .padding(Tokens.Space.md)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                            .stroke(tint.opacity(0.22), lineWidth: 1)
                    )
            )
            .mealgramShadow(Tokens.Shadow.card)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(Text(title))
    }
}
