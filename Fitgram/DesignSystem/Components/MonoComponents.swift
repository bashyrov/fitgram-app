import SwiftUI

// Building blocks for variant D ("Graphite Mono").

/// Small upper-case tracked label ("POZOSTAŁO", "BIAŁKO").
struct MonoLabel: View {
    let text: String
    var onHero = false

    var body: some View {
        Text(text)
            .font(Tokens.Font.manrope(11, weight: 800))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(onHero ? Tokens.Mono.heroMuted : Tokens.Mono.muted)
            .lineLimit(1)
    }
}

/// Section header: "01  OLA" with a hairline underneath and optional trailing content.
struct MonoSectionHeader<Trailing: View>: View {
    let number: String?
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(number: String? = nil, title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.number = number
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if let number {
                Text(number)
                    .font(Tokens.Font.archivo(size: 12, weight: 800, width: 112))
                    .foregroundStyle(Tokens.Mono.muted)
            }
            Text(title)
                .font(Tokens.Font.monoDisplay(22))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Mono.line2).frame(height: 1)
        }
        .padding(.top, Tokens.Space.lg)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

extension MonoSectionHeader where Trailing == EmptyView {
    init(number: String? = nil, title: String) {
        self.init(number: number, title: title) { EmptyView() }
    }
}

/// Light card surface with a hairline border (no glass, no shadow).
struct MonoCardModifier: ViewModifier {
    var radius: CGFloat = Tokens.Mono.Radius.card
    var padding: CGFloat? = Tokens.Space.lg

    func body(content: Content) -> some View {
        content
            .padding(padding ?? 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
    }
}

/// Dark hero surface.
struct MonoHeroModifier: ViewModifier {
    var radius: CGFloat = Tokens.Mono.Radius.hero
    var padding: CGFloat = Tokens.Space.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(Tokens.Mono.onHero)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
    }
}

extension View {
    func monoCard(radius: CGFloat = Tokens.Mono.Radius.card, padding: CGFloat? = Tokens.Space.lg) -> some View {
        modifier(MonoCardModifier(radius: radius, padding: padding))
    }

    func monoHero(radius: CGFloat = Tokens.Mono.Radius.hero, padding: CGFloat = Tokens.Space.lg) -> some View {
        modifier(MonoHeroModifier(radius: radius, padding: padding))
    }
}

/// Skewed segmented progress ("ticks") echoing the FIT logo slant.
struct MonoTicks: View {
    let progress: Double
    var count = 30
    var height: CGFloat = 22
    var fill: Color = Tokens.Mono.hi
    var empty: Color = Tokens.Mono.heroLine

    var body: some View {
        let filled = Int((min(1, max(0, progress)) * Double(count)).rounded())
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index < filled ? fill : empty)
                    .frame(height: height)
                    .transformEffect(CGAffineTransform(a: 1, b: 0, c: -0.42, d: 1, tx: height * 0.21, ty: 0))
            }
        }
        .animation(Tokens.Motion.gentle, value: filled)
        .accessibilityHidden(true)
    }
}

/// Square icon tile used at the start of list rows.
struct MonoIconBox: View {
    enum Style { case outline, dark, accent, track }

    let systemName: String
    var style: Style = .outline
    var size: CGFloat = 40

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.42, weight: .semibold))
            .frame(width: size, height: size)
            .foregroundStyle(foreground)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                    .fill(background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Tokens.Mono.Radius.icon, style: .continuous)
                    .stroke(style == .outline ? Tokens.Mono.line2 : .clear, lineWidth: 1)
            )
    }

    private var foreground: Color {
        switch style {
        case .outline, .track: return Tokens.Palette.ink
        case .dark: return Tokens.Mono.hi
        case .accent: return Tokens.Mono.onAccent
        }
    }

    private var background: Color {
        switch style {
        case .outline: return .clear
        case .dark: return Tokens.Mono.hero
        case .accent: return Tokens.Mono.accent
        case .track: return Tokens.Mono.track
        }
    }
}

/// Thin horizontal progress bar.
struct MonoBar: View {
    let progress: Double
    var color: Color = Tokens.Mono.strong
    var track: Color = Tokens.Mono.track
    var height: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(track)
                Capsule()
                    .fill(color)
                    .frame(width: proxy.size.width * min(1, max(0, progress)))
            }
        }
        .frame(height: height)
        .animation(Tokens.Motion.gentle, value: progress)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Design D uses its own floating tab bar (see `MonoTabBar` in MainTabView):
    /// hide the system bar and leave room at the bottom of every tab.
    func monoTabBarStyle() -> some View {
        self
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 86)
            }
    }
}
