import SwiftUI

struct FriendRow: View {
    let profile: PublicProfile

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                FriendInitialAvatar(name: profile.publicName, size: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(profile.publicName)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailingBadge
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailingBadge: some View {
        if let streak = profile.currentStreak, streak > 0, profile.sharesStreak {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Tokens.Mono.fat)
                Text("\(streak)")
                    .font(Tokens.Font.monoNumber(18))
                    .foregroundStyle(Tokens.Palette.ink)
            }
        } else {
            MonoChevron()
        }
    }

    private var initial: String {
        profile.publicName.first.map { String($0).uppercased() } ?? "?"
    }

    private var subtitle: String {
        if let count = profile.achievementCount, profile.sharesAchievements {
            return String.localizedStringWithFormat(L("%lld badges"), count)
        }
        return "Fitgram"
    }
}

/// Round initial avatar on the track colour (design D friends lists).
struct FriendInitialAvatar: View {
    let name: String
    var size: CGFloat = 40
    var dark = false

    var body: some View {
        Text(initial)
            .font(Tokens.Font.monoNumber(size * 0.4))
            .foregroundStyle(dark ? Tokens.Mono.hi : Tokens.Palette.ink)
            .frame(width: size, height: size)
            .background(Circle().fill(dark ? Tokens.Mono.hero : Tokens.Mono.track))
            .accessibilityHidden(true)
    }

    private var initial: String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}
