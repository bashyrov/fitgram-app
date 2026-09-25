import SwiftUI

/// Square badge used in the Profile grid. Earned badges show full colour;
/// locked badges show a muted treatment + lock glyph so the user knows
/// what's still available.
struct AchievementBadge: View {
    let definition: AchievementDefinition
    let isEarned: Bool
    let earnedAt: Date?

    var body: some View {
        VStack(spacing: Tokens.Space.sm) {
            AchievementMedallion(definition: definition, isEarned: isEarned, size: 68)
            Text(definition.title)
                .font(Tokens.Font.footnote)
                .foregroundStyle(isEarned ? Tokens.Palette.ink : Tokens.Palette.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Tokens.Space.sm)
        .accessibilityElement()
        .accessibilityLabel(Text(definition.title))
        .accessibilityValue(Text(isEarned ? "Zdobyte" : "Zablokowane"))
        .accessibilityHint(Text(definition.summary))
    }
}

struct AchievementMedallion: View {
    let definition: AchievementDefinition
    let isEarned: Bool
    var size: CGFloat = 68
    var showsLock: Bool = true

    private var style: AchievementMedallionStyle {
        AchievementMedallionStyle.style(for: definition.id)
    }

    var body: some View {
        ZStack {
            if isEarned {
                Circle()
                    .fill(style.shadow.opacity(0.24))
                    .blur(radius: size * 0.12)
                    .frame(width: size * 0.92, height: size * 0.92)
                    .offset(y: size * 0.08)
            }

            Circle()
                .fill(outerFill)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .strokeBorder(outerStroke, lineWidth: max(1, size * 0.035))
                }

            Circle()
                .fill(innerFill)
                .frame(width: size * 0.78, height: size * 0.78)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(isEarned ? 0.62 : 0.24), lineWidth: max(1, size * 0.018))
                }

            Image(systemName: definition.symbol)
                .font(.system(size: size * 0.38, weight: .heavy, design: .rounded))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isEarned ? .white : Tokens.Palette.inkSubtle.opacity(0.72))
                .shadow(color: .black.opacity(isEarned ? 0.18 : 0.04), radius: size * 0.05, y: size * 0.025)

            Circle()
                .trim(from: 0.58, to: 0.86)
                .stroke(
                    .white.opacity(isEarned ? 0.55 : 0.16),
                    style: StrokeStyle(lineWidth: max(1, size * 0.035), lineCap: .round)
                )
                .rotationEffect(.degrees(20))
                .frame(width: size * 0.83, height: size * 0.83)

            if isEarned {
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.16, weight: .black))
                    .foregroundStyle(.white.opacity(0.92))
                    .offset(x: size * 0.25, y: -size * 0.25)
            }

            if !isEarned, showsLock {
                Circle()
                    .fill(.black.opacity(0.20))
                    .frame(width: size, height: size)
                lockPlate
            }
        }
        .frame(width: size, height: size)
    }

    private var outerFill: some ShapeStyle {
        if isEarned {
            return AnyShapeStyle(
                AngularGradient(
                    colors: [
                        .white.opacity(0.95),
                        style.top,
                        style.bottom,
                        .white.opacity(0.62),
                        style.top,
                    ],
                    center: .center,
                    angle: .degrees(-35)
                )
            )
        }
        return AnyShapeStyle(Tokens.Palette.surfaceMuted.opacity(0.82))
    }

    private var innerFill: some ShapeStyle {
        if isEarned {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [style.top, style.bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(
            LinearGradient(
                colors: [
                    Tokens.Palette.surface.opacity(0.78),
                    Tokens.Palette.surfaceMuted.opacity(0.92),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var outerStroke: some ShapeStyle {
        if isEarned {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [.white.opacity(0.86), style.bottom.opacity(0.62)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        }
        return AnyShapeStyle(Tokens.Palette.separator.opacity(0.72))
    }

    private var lockPlate: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size * 0.36, height: size * 0.36)
            Circle()
                .strokeBorder(.white.opacity(0.10), lineWidth: 0.35)
                .frame(width: size * 0.36, height: size * 0.36)
            Image(systemName: "lock.fill")
                .font(.system(size: size * 0.16, weight: .black))
                .foregroundStyle(.white)
        }
        .offset(x: size * 0.24, y: size * 0.24)
    }
}

private struct AchievementMedallionStyle {
    let top: Color
    let bottom: Color
    let shadow: Color

    static func style(for id: String) -> AchievementMedallionStyle {
        if id.hasPrefix("streak") {
            return .init(
                top: Tokens.Palette.graphiteSoft, bottom: Tokens.Palette.graphite,
                shadow: Tokens.Palette.graphite)
        }
        if id.hasPrefix("protein") || id.hasPrefix("macros") || id.hasPrefix("calories") {
            return .init(
                top: Tokens.Palette.lime, bottom: Tokens.Palette.mutedGreen,
                shadow: Tokens.Palette.lime)
        }
        if id.hasPrefix("source") || id == "scan.first" || id == "barcode.first" || id == "voice.first"
            || id == "quickdb.first"
        {
            return .init(
                top: Tokens.Palette.graphiteSoft, bottom: Tokens.Palette.mutedGreen,
                shadow: Tokens.Palette.graphite)
        }
        if id.hasPrefix("weight") {
            return .init(
                top: Tokens.Palette.mutedGreen, bottom: Tokens.Palette.graphite,
                shadow: Tokens.Palette.mutedGreen)
        }
        if id.hasPrefix("achievement") {
            return .init(
                top: Tokens.Palette.warning, bottom: Tokens.Palette.graphiteSoft,
                shadow: Tokens.Palette.warning)
        }
        if id.hasPrefix("tag") {
            return .init(
                top: Tokens.Palette.lime.opacity(0.88), bottom: Tokens.Palette.graphiteSoft,
                shadow: Tokens.Palette.lime)
        }
        return .init(top: Tokens.Palette.graphiteSoft, bottom: Tokens.Palette.graphite, shadow: Tokens.Palette.graphite)
    }
}
