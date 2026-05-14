import SwiftUI

/// Polished surface for "Wskazówki od Oli" — gradient avatar puck +
/// summary callout + chip-tip list with per-tip tinted glyph + collapsible
/// extra tips beyond the first 3. Replaces the flat label-on-card variant.
struct OlaInsightsCard: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    @State private var isExpanded: Bool = false

    private var visibleTips: [RecommendationTip] {
        isExpanded ? recommendations.tips : Array(recommendations.tips.prefix(3))
    }

    private var hasMore: Bool {
        recommendations.tips.count > 3
    }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                header
                summaryBlock
                if !recommendations.warnings.isEmpty {
                    warningStrip
                }
                tipsList
                if !recommendations.nextSteps.isEmpty {
                    nextStepsRow
                }
                if hasMore {
                    expandToggle
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.accent.opacity(0.85),
                                Tokens.Palette.accent,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: Tokens.Palette.accent.opacity(0.35), radius: 10, y: 4)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Ola")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("AI Coach")
                        .font(.system(size: 10, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .foregroundStyle(Tokens.Palette.accent)
                        .background(
                            Capsule().fill(Tokens.Palette.accent.opacity(0.15))
                        )
                }
                if let lastUpdated {
                    Text(lastUpdated.formatted(.relative(presentation: .named)))
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
        }
    }

    // MARK: - Summary

    private var summaryBlock: some View {
        Text(recommendations.summary)
            .font(Tokens.Font.body)
            .foregroundStyle(Tokens.Palette.ink)
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.accent.opacity(0.10))
            )
            .overlay(alignment: .topLeading) {
                Rectangle()
                    .fill(Tokens.Palette.accent)
                    .frame(width: 3)
                    .clipShape(
                        UnevenRoundedRectangle(
                            cornerRadii: .init(
                                topLeading: Tokens.Radius.lg,
                                bottomLeading: Tokens.Radius.lg,
                                bottomTrailing: 0,
                                topTrailing: 0
                            ),
                            style: .continuous
                        )
                    )
            }
    }

    // MARK: - Warnings

    private var warningStrip: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(Array(recommendations.warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: Tokens.Space.sm) {
                    ZStack {
                        Circle()
                            .fill(Tokens.Palette.warning.opacity(0.18))
                            .frame(width: 30, height: 30)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Tokens.Palette.warning)
                    }
                    Text(warning)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.warning.opacity(0.08))
                )
            }
        }
    }

    // MARK: - Tips

    private var tipsList: some View {
        VStack(spacing: Tokens.Space.sm) {
            ForEach(visibleTips) { tip in
                tipRow(tip)
            }
        }
    }

    private func tipRow(_ tip: RecommendationTip) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary.opacity(0.15))
                    .frame(width: 36, height: 36)
                Text(tip.icon)
                    .font(.system(size: 18))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(tip.description)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Next steps

    private var nextStepsRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 30, height: 30)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Następny krok")
                    .font(.system(size: 10, weight: .heavy))
                    .textCase(.uppercase)
                    .tracking(1.2)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(recommendations.nextSteps)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
        )
    }

    // MARK: - Expand

    private var expandToggle: some View {
        Button {
            withAnimation(Tokens.Motion.gentle) { isExpanded.toggle() }
            Haptics.light()
        } label: {
            HStack(spacing: 6) {
                Text(isExpanded ? "Pokaż mniej" : "Pokaż wszystkie (\(recommendations.tips.count))")
                    .font(Tokens.Font.footnote.weight(.semibold))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(Tokens.Palette.primary)
            .padding(.horizontal, Tokens.Space.md)
            .padding(.vertical, Tokens.Space.sm)
            .background(
                Capsule().fill(Tokens.Palette.primarySoft)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}
