import SwiftUI

enum OlaAdviceCategory: String, CaseIterable, Identifiable {
    case today
    case protein
    case calories
    case habits
    case memory
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return L("Dziś")
        case .protein: return L("Białko")
        case .calories: return L("Kalorie")
        case .habits: return L("Nawyki")
        case .memory: return L("Pamięć")
        case .history: return L("Historia")
        }
    }

    var symbol: String {
        switch self {
        case .today: return "sparkles"
        case .protein: return "bolt.heart.fill"
        case .calories: return "gauge.with.dots.needle.67percent"
        case .habits: return "checkmark.seal.fill"
        case .memory: return "brain.head.profile"
        case .history: return "clock.arrow.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .today: return Tokens.Palette.primary
        case .protein: return Tokens.Palette.accent
        case .calories: return Tokens.Palette.warning
        case .habits: return Tokens.Palette.success
        case .memory: return Tokens.Palette.primary
        case .history: return Tokens.Palette.ink
        }
    }

    var keywords: [String] {
        switch self {
        case .today, .memory, .history:
            return []
        case .protein:
            return ["biał", "protein", "twar", "jogurt", "skyr", "mięs", "ryb"]
        case .calories:
            return ["kcal", "kalor", "energia", "deficyt", "nadwyż", "tempo", "cel"]
        case .habits:
            return ["woda", "ruch", "sen", "spacer", "warzy", "błonnik", "regular"]
        }
    }
}

struct OlaLivingHero: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.lg) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 60, height: 60)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .heavy))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Ola")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L("Twój spokojny coach od decyzji żywieniowych"))
                        .font(Tokens.Font.subheadline)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }

            Text(L(recommendations.summary))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Tokens.Palette.ink)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: Tokens.Space.sm) {
                heroPill(symbol: "brain.head.profile", text: L("Pamięta kontekst"))
                heroPill(symbol: "hand.thumbsup.fill", text: L("Uczy się z reakcji"))
            }

            if !recommendations.nextSteps.isEmpty {
                HStack(spacing: Tokens.Space.sm) {
                    Image(systemName: "arrow.right.circle.fill")
                        .foregroundStyle(Tokens.Palette.primary)
                    Text(L(recommendations.nextSteps))
                        .font(Tokens.Font.footnote.weight(.semibold))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(3)
                }
                .padding(Tokens.Space.md)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Tokens.Palette.surface.opacity(0.62))
                )
            }
        }
        .padding(Tokens.Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Tokens.Palette.surface.opacity(0.78)))
        .overlay(alignment: .topTrailing) {
            Text(lastUpdated?.formatted(.relative(presentation: .named)) ?? L("Na żywo"))
                .font(Tokens.Font.caption.weight(.bold))
                .foregroundStyle(Tokens.Palette.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Capsule().fill(Tokens.Palette.primarySoft))
                .padding(Tokens.Space.md)
        }
        .shadow(color: Tokens.Palette.primary.opacity(0.13), radius: 26, y: 16)
    }

    private func heroPill(symbol: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(Tokens.Font.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Tokens.Palette.ink)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Capsule().fill(Tokens.Palette.primarySoft.opacity(0.8)))
    }
}

struct OlaAdviceCard: View {
    let tip: RecommendationTip
    let isHelpful: Bool
    let isNotHelpful: Bool
    let onHelpful: () -> Void
    let onNotHelpful: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top, spacing: Tokens.Space.md) {
                Text(tip.icon)
                    .font(.system(size: 28))
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Tokens.Palette.primarySoft))
                VStack(alignment: .leading, spacing: 6) {
                    Text(L(tip.title))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(L(tip.description))
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: Tokens.Space.sm) {
                reactionButton(
                    title: L("Pomocne"),
                    symbol: "hand.thumbsup.fill",
                    tint: Tokens.Palette.success,
                    selected: isHelpful,
                    action: onHelpful
                )
                reactionButton(
                    title: L("Nie teraz"),
                    symbol: "hand.thumbsdown.fill",
                    tint: Tokens.Palette.inkMuted,
                    selected: isNotHelpful,
                    action: onNotHelpful
                )
                Spacer(minLength: 0)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.84)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.34), lineWidth: 1))
        .shadow(color: Tokens.Palette.primary.opacity(0.06), radius: 14, y: 8)
    }

    private func reactionButton(
        title: String,
        symbol: String,
        tint: Color,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Tokens.Font.caption.weight(.bold))
            }
            .foregroundStyle(selected ? .white : tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Capsule().fill(selected ? tint : tint.opacity(0.12)))
        }
        .buttonStyle(.pressable)
    }
}

struct OlaMemoryRow: View {
    let symbol: String
    let title: LocalizedStringKey
    let value: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.md) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint.opacity(0.14)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(L(value))
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Tokens.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Tokens.Palette.surface.opacity(0.82)))
    }
}
