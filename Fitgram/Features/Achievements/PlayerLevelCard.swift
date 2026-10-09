import SwiftUI

/// Dark hero card: player level, rank title and XP progress to the next
/// level. XP comes from earned badges (`AchievementXP`).
struct PlayerLevelCard: View {
    let earnedIDs: [String]

    private var progress: AchievementXP.Progress {
        AchievementXP.progress(xp: AchievementXP.total(earnedIDs: earnedIDs))
    }

    var body: some View {
        let progress = progress
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                Text(verbatim: "\(progress.level)")
                    .font(Tokens.Font.monoNumber(30))
                    .foregroundStyle(Tokens.Mono.hero)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Tokens.Mono.hi))
                VStack(alignment: .leading, spacing: 4) {
                    Text(TL(pl: "Poziom", en: "Level", uk: "Рівень", ru: "Уровень", es: "Nivel") + " \(progress.level)")
                        .font(Tokens.Font.manrope(12, weight: 800))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(Tokens.Mono.heroMuted)
                    Text(AchievementXP.rankTitle(forLevel: progress.level))
                        .font(Tokens.Font.monoDisplay(24))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: "\(progress.xp)")
                        .font(Tokens.Font.monoNumber(22))
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text(verbatim: "XP")
                        .font(Tokens.Font.manrope(11, weight: 800))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                }
            }
            MonoTicks(progress: progress.fraction, count: 30, height: 12)
            Text(
                TL(
                    pl: "\(progress.nextLevelXP - progress.xp) XP do poziomu \(progress.level + 1)",
                    en: "\(progress.nextLevelXP - progress.xp) XP to level \(progress.level + 1)",
                    uk: "\(progress.nextLevelXP - progress.xp) XP до рівня \(progress.level + 1)",
                    ru: "\(progress.nextLevelXP - progress.xp) XP до уровня \(progress.level + 1)",
                    es: "\(progress.nextLevelXP - progress.xp) XP para el nivel \(progress.level + 1)")
            )
            .font(Tokens.Font.manrope(12, weight: 700))
            .foregroundStyle(Tokens.Mono.heroMuted)
        }
        .monoHero(padding: 18)
        .accessibilityElement(children: .combine)
    }
}

/// One leveled track in the "Levels" tab: icon, "Level 3 / 8", ticks to the
/// next threshold and the raw value.
struct AchievementTrackRow: View {
    let track: AchievementTrack
    let value: Int

    var body: some View {
        let level = track.level(for: value)
        let next = track.nextThreshold(after: value)
        let previous = level > 0 ? track.thresholds[level - 1] : 0
        let fraction = next.map { Double(value - previous) / Double(max(1, $0 - previous)) } ?? 1
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: track.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(level > 0 ? Tokens.Mono.hi : Tokens.Mono.muted)
                .frame(width: 48, height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(level > 0 ? Tokens.Mono.hero : Tokens.Mono.track)
                )
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(track.title)
                        .font(Tokens.Font.manrope(14, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    Text(level > 0 ? AchievementTracks.roman(level) : "–")
                        .font(Tokens.Font.monoNumber(15))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(verbatim: "/ \(AchievementTracks.roman(track.maxLevel))")
                        .font(Tokens.Font.manrope(11, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                MonoTicks(
                    progress: min(1, max(0, fraction)), count: 24, height: 8, fill: Tokens.Mono.strong,
                    empty: Tokens.Mono.track)
                Text(
                    next.map { "\(AchievementTracks.formatted(value)) / \(AchievementTracks.formatted($0))" }
                        ?? TL(
                            pl: "Maksymalny poziom", en: "Max level", uk: "Максимальний рівень",
                            ru: "Максимальный уровень", es: "Nivel máximo")
                )
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
        }
        .monoCard(padding: 12)
        .accessibilityElement(children: .combine)
    }
}
