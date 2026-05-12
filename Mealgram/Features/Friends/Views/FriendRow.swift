import SwiftUI

struct FriendRow: View {
    let profile: PublicProfile

    var body: some View {
        HStack(spacing: Tokens.Space.md) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let streak = profile.currentStreak, streak > 0, profile.sharesStreak {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("\(streak)")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                .padding(.horizontal, Tokens.Space.sm)
                .padding(.vertical, 2)
                .background(Capsule().fill(Tokens.Palette.warning.opacity(0.15)))
            }
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .stroke(Tokens.Palette.separator, lineWidth: 1)
        )
    }

    private var avatar: some View {
        Circle()
            .fill(Tokens.Palette.primarySoft)
            .frame(width: 40, height: 40)
            .overlay(
                Text(initial)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.primary)
            )
    }

    private var initial: String {
        profile.displayName.first.map { String($0).uppercased() } ?? "?"
    }

    private var subtitle: String {
        if let count = profile.achievementCount, profile.sharesAchievements {
            return "\(count) odznak"
        }
        return "Mealgram"
    }
}
