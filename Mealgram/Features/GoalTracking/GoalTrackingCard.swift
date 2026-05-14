import Charts
import SwiftUI

/// Compact "Twój cel · zobacz postęp" card on Today. Tappable; opens the
/// full GoalTrackingView. Shows current vs. target weight, a 14-day
/// sparkline, and days-elapsed / total-days.
struct GoalTrackingCard: View {
    let snapshot: GoalTrackingService.Snapshot
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card(elevation: Tokens.Shadow.card) {
                VStack(alignment: .leading, spacing: Tokens.Space.sm) {
                    HStack(spacing: Tokens.Space.sm) {
                        Image(systemName: "target")
                            .foregroundStyle(Tokens.Palette.primary)
                        Text("Twój cel · zobacz postęp")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Tokens.Palette.inkSubtle)
                    }
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
            }
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("Twój cel — zobacz postęp"))
    }

    private var daysLabel: String {
        if let total = snapshot.totalDays, total > 0 {
            return String(
                localized: "Dzień \(snapshot.daysElapsed) z \(total)"
            )
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

/// Free-tier CTA card that takes the GoalTrackingCard slot when the user
/// has a lose/gain goal but no Premium entitlement. Tap raises the
/// PaywallCoordinator with `.goalTracking`.
struct GoalTrackingUpsellCard: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            Card(background: Tokens.Palette.primarySoft, elevation: Tokens.Shadow.card) {
                HStack(spacing: Tokens.Space.md) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Premium odblokuje śledzenie celu")
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text("Codzienna waga, wykres trendu, przypomnienie.")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Tokens.Palette.primary)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}
