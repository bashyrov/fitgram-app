import SwiftUI

/// Hero "Porady od Oli" panel for Today. Full-bleed gradient with a
/// large avatar puck, paginated tip carousel, page-dot indicator, and
/// a dominant "Następny krok" CTA strip. Built to be the second-most
/// eye-catching surface on Today after the calorie ring.
struct OlaInsightsHero: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    @State private var pageIndex: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            headerStrip
            summaryBlock
            if !recommendations.warnings.isEmpty {
                warningStrip
                    .padding(.horizontal, Tokens.Space.lg)
                    .padding(.top, Tokens.Space.md)
            }
            tipCarousel
            if !recommendations.nextSteps.isEmpty {
                nextStepStrip
            }
        }
        .background(heroBackground)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
    }

    // MARK: - Background

    private var heroBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                .fill(Tokens.Palette.surface)
            // Ambient gradient blob top-right (accent)
            Circle()
                .fill(Tokens.Palette.accent.opacity(0.45))
                .frame(width: 220, height: 220)
                .blur(radius: 80)
                .offset(x: 110, y: -100)
            // Ambient gradient blob bottom-left (primary)
            Circle()
                .fill(Tokens.Palette.primary.opacity(0.35))
                .frame(width: 200, height: 200)
                .blur(radius: 80)
                .offset(x: -120, y: 120)
            // Soft top sheen to lift the avatar
            LinearGradient(
                colors: [Color.white.opacity(0.30), .clear],
                startPoint: .top,
                endPoint: .center
            )
            .blendMode(.overlay)
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous))
        .shadow(color: Tokens.Palette.accent.opacity(0.18), radius: 24, y: 12)
    }

    // MARK: - Header

    private var headerStrip: some View {
        HStack(spacing: Tokens.Space.md) {
            avatarPuck
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Porady od Oli")
                        .font(Tokens.Font.headline)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("AI Coach")
                        .font(.system(size: 9, weight: .heavy))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .foregroundStyle(.white)
                        .background(
                            Capsule().fill(Tokens.Palette.accent)
                        )
                }
                if let lastUpdated {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Tokens.Palette.success)
                            .frame(width: 5, height: 5)
                        Text("Aktualne · \(lastUpdated.formatted(.relative(presentation: .named)))")
                            .font(Tokens.Font.caption)
                            .foregroundStyle(Tokens.Palette.inkMuted)
                    }
                } else {
                    Text("Twój asystent AI")
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Tokens.Space.lg)
        .padding(.top, Tokens.Space.lg)
        .padding(.bottom, Tokens.Space.md)
    }

    private var avatarPuck: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Tokens.Palette.accent,
                            Tokens.Palette.accent.opacity(0.7),
                            Tokens.Palette.primary.opacity(0.8),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
                .shadow(color: Tokens.Palette.accent.opacity(0.45), radius: 12, y: 6)
            Image(systemName: "sparkles")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Summary

    private var summaryBlock: some View {
        Text(L(recommendations.summary))
            .font(.system(size: 19, weight: .semibold, design: .rounded))
            .foregroundStyle(Tokens.Palette.ink)
            .lineSpacing(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.lg)
    }

    // MARK: - Warnings

    private var warningStrip: some View {
        VStack(spacing: 6) {
            ForEach(Array(recommendations.warnings.enumerated()), id: \.offset) { _, warning in
                HStack(alignment: .top, spacing: Tokens.Space.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text(L(warning))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(Tokens.Space.sm)
                .background(
                    RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                        .fill(Tokens.Palette.warning.opacity(0.15))
                )
            }
        }
    }

    // MARK: - Tip carousel

    private var tipCarousel: some View {
        VStack(spacing: Tokens.Space.sm) {
            TabView(selection: $pageIndex) {
                ForEach(Array(recommendations.tips.enumerated()), id: \.offset) { idx, tip in
                    tipCard(tip)
                        .tag(idx)
                        .padding(.horizontal, Tokens.Space.lg)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 180)

            if recommendations.tips.count > 1 {
                pageDots
            }
        }
        .padding(.top, Tokens.Space.lg)
    }

    private func tipCard(_ tip: RecommendationTip) -> some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Tokens.Palette.primary.opacity(0.18),
                                Tokens.Palette.accent.opacity(0.18),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                Text(tip.icon)
                    .font(.system(size: 28))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L(tip.title))
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                Text(L(tip.description))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Color.white.opacity(0.65))
        )
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<recommendations.tips.count, id: \.self) { idx in
                Capsule()
                    .fill(pageIndex == idx ? Tokens.Palette.accent : Tokens.Palette.inkSubtle.opacity(0.35))
                    .frame(width: pageIndex == idx ? 18 : 6, height: 6)
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: pageIndex)
            }
        }
        .padding(.bottom, Tokens.Space.sm)
    }

    // MARK: - Next step

    private var nextStepStrip: some View {
        HStack(spacing: Tokens.Space.md) {
            ZStack {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 36, height: 36)
                    .shadow(color: Tokens.Palette.primary.opacity(0.45), radius: 8, y: 3)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("NASTĘPNY KROK")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.4)
                    .foregroundStyle(Tokens.Palette.primary)
                Text(L(recommendations.nextSteps))
                    .font(Tokens.Font.body.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Rectangle()
                .fill(Tokens.Palette.primarySoft)
        )
        .padding(.top, Tokens.Space.md)
    }
}
