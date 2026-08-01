import SwiftUI

struct FriendRow: View {
    let profile: PublicProfile

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            avatar
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            trailingBadge
        }
        .padding(Tokens.Space.md)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.34), lineWidth: 1)
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.06), radius: 14, y: 8)
    }

    private var avatar: some View {
        Text(initial)
            .font(.system(size: 17, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(
                Circle().fill(
                    LinearGradient(
                        colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            )
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if let streak = profile.currentStreak, streak > 0, profile.sharesStreak {
            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Tokens.Palette.warning)
                Text("\(streak)")
                    .font(Tokens.Font.caption.weight(.bold))
                    .foregroundStyle(Tokens.Palette.ink)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Tokens.Palette.warning.opacity(0.15)))
        } else {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private var initial: String {
        profile.displayName.first.map { String($0).uppercased() } ?? "?"
    }

    private var subtitle: String {
        if let count = profile.achievementCount, profile.sharesAchievements {
            return String.localizedStringWithFormat(L("%lld badges"), count)
        }
        return "Mealgram"
    }
}
