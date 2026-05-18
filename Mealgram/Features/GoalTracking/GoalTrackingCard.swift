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
            Card(elevation: Tokens.Shadow.card) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    header
                    weightRow
                    daysRow
                    if !tips.isEmpty {
                        Divider()
                            .padding(.vertical, 2)
                        tipsBlock
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Twój cel — zobacz postęp"))
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "target")
                .foregroundStyle(Tokens.Palette.primary)
            Text("Twój cel · AI")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(Tokens.Palette.inkSubtle)
        }
    }

    private var weightRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Teraz")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(String(format: "%.1f kg", snapshot.currentWeightKg))
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cel")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(String(format: "%.1f kg", snapshot.targetWeightKg))
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            Spacer(minLength: Tokens.Space.sm)
            sparkline
        }
    }

    private var daysRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "calendar")
                .font(.caption2)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            Text(daysLabel)
                .font(Tokens.Font.caption)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            if snapshot.isGoalReached {
                Text("Cel osiągnięty")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.success)
            }
        }
    }

    /// Compact list of 2–3 AI recommendations rendered as
    /// emoji-chip · title rows. Keeps each line short — the user opens
    /// the full sheet for bodies.
    private var tipsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.accent)
                Text("Co pomoże dziś")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.accent)
            }
            ForEach(Array(tips.prefix(3).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 8) {
                    Text(tip.icon)
                        .font(.system(size: 14))
                    Text(tip.title)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var daysLabel: String {
        if let total = snapshot.totalDays, total > 0 {
            return String(localized: "Dzień \(snapshot.daysElapsed) z \(total)")
        }
        return String(localized: "Dzień \(snapshot.daysElapsed)")
    }

    @ViewBuilder
    private var sparkline: some View {
        let points = snapshot.last14Days
        if points.count >= 2 {
            Chart(points) { point in
                LineMark(
                    x: .value("Data", point.date),
                    y: .value("Waga", point.weightKg)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Tokens.Palette.primary)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartPlotStyle { $0.background(Color.clear) }
            .frame(width: 92, height: 36)
        } else {
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 92, height: 36)
                .overlay(
                    Text("—")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                )
        }
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card(elevation: Tokens.Shadow.card) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    header
                    ZStack {
                        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                            placeholderWeightRow
                            placeholderTipsBlock
                        }
                        .blur(radius: 6)
                        .allowsHitTesting(false)
                        premiumChip
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Twój cel — odblokuj w Premium"))
    }

    private var header: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "target")
                .foregroundStyle(Tokens.Palette.primary)
            Text("Twój cel · AI")
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
            Image(systemName: "lock.fill")
                .foregroundStyle(Tokens.Palette.primary)
        }
    }

    private var placeholderWeightRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Teraz")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(currentWeightKg.map { String(format: "%.1f kg", $0) } ?? "— kg")
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundStyle(Tokens.Palette.inkSubtle)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cel")
                    .font(Tokens.Font.caption)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(targetWeightKg.map { String(format: "%.1f kg", $0) } ?? "— kg")
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.primary)
            }
            Spacer(minLength: Tokens.Space.sm)
            RoundedRectangle(cornerRadius: Tokens.Radius.sm, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
                .frame(width: 92, height: 36)
        }
    }

    private var placeholderTipsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Tokens.Palette.accent)
                Text("Co pomoże dziś")
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Palette.accent)
            }
            ForEach(0..<3, id: \.self) { _ in
                HStack(alignment: .top, spacing: 8) {
                    Text("✦")
                        .font(.system(size: 14))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Tokens.Palette.separator)
                        .frame(height: 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var premiumChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
            Text("Odblokuj Premium")
                .font(.system(size: 12, weight: .heavy))
                .tracking(0.5)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        )
        .shadow(color: Tokens.Palette.primary.opacity(0.4), radius: 8, y: 3)
    }
}
