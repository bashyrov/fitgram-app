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

/// Dark hero at the top of "Porady od Oli" (design D): Ola avatar box, name, pills and live status line.
struct OlaLivingHero: View {
    let recommendations: Recommendations
    let lastUpdated: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                MonoIconBox(systemName: "sparkles", style: .hi, size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ola")
                        .font(Tokens.Font.monoNumber(30))
                        .textCase(.uppercase)
                        .foregroundStyle(Tokens.Mono.onHero)
                    Text(L("Twój spokojny coach od decyzji żywieniowych"))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.heroMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            if !recommendations.summary.isEmpty {
                Text(L(recommendations.summary))
                    .font(Tokens.Font.manrope(15, weight: 700))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                heroPill(symbol: "clock.arrow.circlepath", text: L("Pamięta kontekst"))
                heroPill(symbol: "hand.thumbsup", text: L("Uczy się z reakcji"))
            }

            if !recommendations.nextSteps.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Tokens.Mono.hi)
                    Text(L(recommendations.nextSteps))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.onHero)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Tokens.Mono.heroLine, lineWidth: 1)
                )
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color(red: 0.247, green: 0.639, blue: 0.357))
                    .frame(width: 7, height: 7)
                Text(liveText)
                    .font(Tokens.Font.manrope(12, weight: 700))
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .lineLimit(1)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
    }

    private var liveText: String {
        guard let lastUpdated else { return L("Na żywo") }
        return L("Na żywo") + " · " + lastUpdated.formatted(.relative(presentation: .named))
    }

    private func heroPill(symbol: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .bold))
            Text(text)
                .font(Tokens.Font.manrope(12, weight: 700))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(Tokens.Mono.onHero)
        .padding(.horizontal, 10)
        .frame(height: 28)
        .background(Capsule().fill(Tokens.Mono.heroLine))
    }
}

/// Tip card (lib `tip`): track icon box, category label, 16/800 title, muted body and two
/// outline feedback pills ("Pomocne" / "Nie teraz").
struct OlaAdviceCard: View {
    let tip: RecommendationTip
    let isHelpful: Bool
    let isNotHelpful: Bool
    let onHelpful: () -> Void
    let onNotHelpful: () -> Void
    var category: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                OlaEmojiBox(emoji: tip.icon)
                VStack(alignment: .leading, spacing: 4) {
                    if let category {
                        MonoLabel(text: category)
                    }
                    Text(L(tip.title))
                        .font(Tokens.Font.manrope(16, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(L(tip.description))
                        .font(Tokens.Font.manrope(13, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 6) {
                reactionButton(title: L("Pomocne"), symbol: "hand.thumbsup", selected: isHelpful, action: onHelpful)
                reactionButton(title: L("Nie teraz"), symbol: nil, selected: isNotHelpful, action: onNotHelpful)
                Spacer(minLength: 0)
            }
        }
        .monoCard(padding: 16)
    }

    private func reactionButton(
        title: String,
        symbol: String?,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: selected ? symbol + ".fill" : symbol)
                        .font(.system(size: 12, weight: .bold))
                }
                Text(title)
                    .font(Tokens.Font.manrope(12, weight: 800))
            }
            .foregroundStyle(selected ? Tokens.Mono.onHero : Tokens.Palette.ink)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .background(Capsule().fill(selected ? Tokens.Mono.hero : Color.clear))
            .overlay(Capsule().stroke(selected ? Color.clear : Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// One row of the "Pamięć Oli" card — rendered as a design-D list row (outline icon box).
struct OlaMemoryRow: View {
    let symbol: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        MonoRow(icon: symbol, title: title, sub: L(value)) {
            EmptyView()
        }
    }
}

/// Emoji glyph inside a 40 pt track icon box (lib `icbox(…, 'track')`) — tips carry emoji, not SF Symbols.
struct OlaEmojiBox: View {
    let emoji: String
    var size: CGFloat = 40

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.45))
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                    .fill(Tokens.Mono.track)
            )
    }
}
