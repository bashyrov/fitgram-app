import Charts
import SwiftUI

/// Goal-tracking block on Today.
///
/// The Premium version shows: a "Twój cel · AI" header, the current/target
/// weight pair, a 14-day sparkline, days-elapsed counter, and 2–3 short
/// AI-driven tips tailored to the user's goal kind and progress. The
/// whole card is tappable and opens the full `GoalTrackingView`.
///
/// The free-tier variant (`GoalTrackingPeekCard`) keeps the same header
/// so non-Premium users still see the block on Today and understand
/// what they're missing — the body is blurred and a Premium lock chip
/// overlays it; tap raises the paywall.
struct GoalTrackingCard: View {
    let snapshot: GoalTrackingService.Snapshot
    /// Up to 3 short, goal-relevant tips drawn from the user's cached
    /// recommendations. Caller passes the first N — the card renders
    /// title + body lines (no icon recoloring) to stay compact.
    var tips: [RecommendationTip] = []
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                header
                weightRow
                if !tips.isEmpty {
                    tipsBlock
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .monoCard(padding: 16)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Twój cel — zobacz postęp"))
    }

    /// Mockup: "TWÓJ CEL · AI" label left, "Dzień 12 z 90" muted right.
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            MonoLabel(text: L("Twój cel · AI"))
            Spacer(minLength: 8)
            if snapshot.isGoalReached {
                Text("Goal reached")
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .foregroundStyle(Tokens.Palette.success)
                    .lineLimit(1)
            }
            Text(daysLabel)
                .font(Tokens.Font.manrope(12, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
                .lineLimit(1)
        }
    }

    /// Mockup: "Teraz 68,4 kg" — progress bar — "Cel 62 kg".
    private var weightRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            GoalWeightColumn(label: "Teraz", weightKg: snapshot.currentWeightKg, alignment: .leading)
            MonoBar(progress: snapshot.progress, color: Tokens.Mono.strong, track: Tokens.Mono.track, height: 6)
                .padding(.bottom, 10)
            GoalWeightColumn(label: "Goal", weightKg: snapshot.targetWeightKg, alignment: .trailing)
        }
    }

    /// Mockup "Co pomoże dziś": hairline on top, accent ✦ + 13/600 tip titles.
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            MonoLabel(text: L("What helps today"))
            ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "✦")
                        .font(Tokens.Font.manrope(13, weight: 800))
                        .foregroundStyle(Tokens.Mono.accent)
                    Text(L(tip.title))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineSpacing(2)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.top, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Rectangle().fill(Tokens.Mono.line).frame(height: 1)
        }
    }

    private var daysLabel: String {
        if let total = snapshot.totalDays, total > 0 {
            return String.localizedStringWithFormat(L("Day %lld of %lld"), snapshot.daysElapsed, total)
        }
        return String.localizedStringWithFormat(L("Day %lld"), snapshot.daysElapsed)
    }
}

/// Free-tier "peek" of the goal-tracking block. Header stays sharp so
/// the user understands what's behind the gate; the body is blurred,
/// a Premium lock chip overlays it, the whole card taps into the
/// paywall. Same vertical footprint as the Premium card so the Today
/// scroll layout doesn't jump after upgrade.
struct GoalTrackingPeekCard: View {
    /// Used to draw a believable shadowed body — current/target taken
    /// from the user's goal even though we won't show them sharply.
    let currentWeightKg: Double?
    let targetWeightKg: Double?
    var isLocked: Bool = true
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 14) {
                header
                ZStack {
                    VStack(alignment: .leading, spacing: 14) {
                        placeholderWeightRow
                        placeholderTipsLine
                    }
                    .blur(radius: 5)
                    .opacity(0.7)
                    .allowsHitTesting(false)
                    if !isLocked {
                        actionChip
                    }
                }
                .clipped()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .monoCard(padding: 16)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(isLocked ? "Twój cel — Pro" : "Twój cel"))
    }

    private var header: some View {
        HStack(spacing: 8) {
            MonoLabel(text: L("Twój cel · AI"))
            Spacer(minLength: 8)
            if isLocked {
                premiumHint
            } else {
                MonoChevron()
            }
        }
    }

    /// Mockup PRO badge: 22 pt hero chip, hi lock + "PRO".
    private var premiumHint: some View {
        HStack(spacing: 4) {
            Image(systemName: "lock.fill")
                .font(.system(size: 9, weight: .bold))
            Text("PRO")
                .font(Tokens.Font.manrope(10, weight: 800))
                .tracking(0.8)
        }
        .foregroundStyle(Tokens.Mono.hi)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Tokens.Mono.hero)
        )
    }

    private var placeholderWeightRow: some View {
        HStack(alignment: .bottom, spacing: 12) {
            Text(currentWeightKg.map { String(format: "%.1f kg", $0) } ?? "— kg")
                .font(Tokens.Font.monoNumber(26))
                .foregroundStyle(Tokens.Palette.ink)
            Capsule()
                .fill(Tokens.Mono.strong)
                .frame(height: 6)
                .padding(.bottom, 8)
            Text(targetWeightKg.map { String(format: "%.1f kg", $0) } ?? "— kg")
                .font(Tokens.Font.monoNumber(26))
                .foregroundStyle(Tokens.Palette.ink)
        }
    }

    private var placeholderTipsLine: some View {
        Text(verbatim: "✦ ••••••••• · ✦ ••••••••• · ✦ •••••••••")
            .font(Tokens.Font.manrope(13, weight: 600))
            .foregroundStyle(Tokens.Palette.ink)
            .lineLimit(1)
    }

    private var actionChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "target")
                .font(.system(size: 12, weight: .bold))
            Text("Otwórz cel")
                .font(Tokens.Font.manrope(12, weight: 800))
        }
        .foregroundStyle(Tokens.Mono.hi)
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .background(Capsule().fill(Tokens.Mono.hero))
    }
}

/// "Teraz / Cel" column: 11/700 muted caption over a 26 pt italic number + 13 pt "kg".
private struct GoalWeightColumn: View {
    let label: LocalizedStringKey
    let weightKg: Double
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(label)
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", weightKg))
                    .font(Tokens.Font.monoNumber(26))
                Text(verbatim: "kg")
                    .font(Tokens.Font.manrope(13, weight: 700))
            }
            .foregroundStyle(Tokens.Palette.ink)
            .lineLimit(1)
        }
        .fixedSize()
    }
}
