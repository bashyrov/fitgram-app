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
                .strokeBorder(.white.opacity(0.38), lineWidth: 1)
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
                top: Color(red: 1.00, green: 0.70, blue: 0.22), bottom: Color(red: 0.93, green: 0.29, blue: 0.18),
                shadow: Color(red: 0.96, green: 0.42, blue: 0.16))
        }
        if id.hasPrefix("protein") || id.hasPrefix("macros") || id.hasPrefix("calories") {
            return .init(
                top: Color(red: 0.30, green: 0.84, blue: 0.68), bottom: Color(red: 0.06, green: 0.52, blue: 0.44),
                shadow: Color(red: 0.10, green: 0.68, blue: 0.55))
        }
        if id.hasPrefix("source") || id == "scan.first" || id == "barcode.first" || id == "voice.first"
            || id == "quickdb.first"
        {
            return .init(
                top: Color(red: 0.45, green: 0.69, blue: 1.00), bottom: Color(red: 0.32, green: 0.33, blue: 0.88),
                shadow: Color(red: 0.33, green: 0.47, blue: 0.94))
        }
        if id.hasPrefix("weight") {
            return .init(
                top: Color(red: 0.54, green: 0.72, blue: 1.00), bottom: Color(red: 0.34, green: 0.41, blue: 0.74),
                shadow: Color(red: 0.37, green: 0.48, blue: 0.82))
        }
        if id.hasPrefix("achievement") {
            return .init(
                top: Color(red: 1.00, green: 0.82, blue: 0.35), bottom: Color(red: 0.82, green: 0.54, blue: 0.12),
                shadow: Color(red: 0.95, green: 0.64, blue: 0.20))
        }
        if id.hasPrefix("tag") {
            return .init(
                top: Color(red: 0.67, green: 0.77, blue: 0.70), bottom: Color(red: 0.34, green: 0.52, blue: 0.42),
                shadow: Color(red: 0.36, green: 0.58, blue: 0.45))
        }
        return .init(top: Tokens.Palette.primary, bottom: Tokens.Palette.accent, shadow: Tokens.Palette.primary)
    }
}
