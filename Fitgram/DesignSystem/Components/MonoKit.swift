import SwiftUI

// swiftlint:disable file_length

// Design D kit — SwiftUI twins of the mockup library (lib.py) so every screen can be
// composed 1:1 with the canvas templates. Margins follow the mockups: cards sit 12 pt
// from the screen edge (`Tokens.Space.screenPadding`), text blocks get +6 pt inset.

// MARK: - Headline (h1)

/// Big italic upper-case page title with optional kicker label and subtitle.
struct MonoH1: View {
    let text: String
    var sub: String?
    var kicker: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let kicker {
                MonoLabel(text: kicker)
            }
            Text(text)
                .font(Tokens.Font.monoDisplay(30))
                .textCase(.uppercase)
                .foregroundStyle(Tokens.Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let sub {
                Text(sub)
                    .font(Tokens.Font.manrope(14, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 6)
        .padding(.top, 14)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Rows (settings-style list inside one card)

/// One list row: icon box, title, optional subtitle and a trailing view (chevron by default).
struct MonoRow<Trailing: View>: View {
    var icon: String?
    var iconStyle: MonoIconBox.Style = .outline
    let title: String
    var sub: String?
    var titleColor: Color = Tokens.Palette.ink
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                MonoIconBox(systemName: icon, style: iconStyle, size: 40)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(titleColor)
                    .fixedSize(horizontal: false, vertical: true)
                if let sub {
                    Text(sub)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

extension MonoRow where Trailing == MonoChevron {
    init(
        icon: String? = nil, iconStyle: MonoIconBox.Style = .outline, title: String, sub: String? = nil,
        titleColor: Color = Tokens.Palette.ink
    ) {
        self.init(icon: icon, iconStyle: iconStyle, title: title, sub: sub, titleColor: titleColor) { MonoChevron() }
    }
}

struct MonoChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(Tokens.Mono.muted)
    }
}

/// Hairline between rows, inset past the icon box.
struct MonoRowDivider: View {
    var inset: CGFloat = 68

    var body: some View {
        Rectangle()
            .fill(Tokens.Mono.line)
            .frame(height: 1)
            .padding(.leading, inset)
    }
}

extension View {
    /// Card container for a stack of `MonoRow`s (no inner padding, clipped).
    func monoRowsCard(radius: CGFloat = Tokens.Mono.Radius.card) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
    }

    /// Small grid tile: card with 20 pt radius and 14 pt padding.
    func monoTile(padding: CGFloat = 14) -> some View {
        monoCard(radius: Tokens.Mono.Radius.tile, padding: padding)
    }
}

// MARK: - Buttons

enum MonoButtonKind {
    case dark, accent, outline, danger, hi, ghost

    var background: Color {
        switch self {
        case .dark: return Tokens.Mono.hero
        case .accent: return Tokens.Mono.accent
        case .hi: return Tokens.Mono.hi
        case .outline, .danger, .ghost: return .clear
        }
    }

    var foreground: Color {
        switch self {
        case .dark: return Tokens.Mono.onHero
        case .accent: return Tokens.Mono.onAccent
        case .hi: return Tokens.Mono.onHi
        case .outline: return Tokens.Palette.ink
        case .danger: return Tokens.Mono.danger
        case .ghost: return Tokens.Mono.muted
        }
    }

    var border: Color {
        switch self {
        case .outline: return Tokens.Mono.line2
        case .danger: return Tokens.Mono.danger.opacity(0.35)
        default: return .clear
        }
    }
}

/// Capsule button style from the mockups (52 pt, 15/800).
struct MonoButtonStyle: ButtonStyle {
    var kind: MonoButtonKind = .dark
    var height: CGFloat = 52
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Tokens.Font.manrope(15, weight: 800))
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, 18)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(Capsule().fill(kind.background))
            .overlay(Capsule().stroke(kind.border, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Convenience capsule button: icon + title.
struct MonoButton: View {
    let title: String
    var kind: MonoButtonKind = .dark
    var icon: String?
    var height: CGFloat = 52
    var fullWidth = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 15, weight: .bold))
                }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .buttonStyle(MonoButtonStyle(kind: kind, height: height, fullWidth: fullWidth))
    }
}

/// Bottom action area used by sheets ("Dodaj do dziennika" + secondary).
struct MonoBottomBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 8) {
            content()
        }
        .padding(.horizontal, Tokens.Space.screenPadding)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Tokens.Palette.background.ignoresSafeArea(edges: .bottom))
    }
}

// MARK: - Navigation bar items

/// Dark pill used as the right navigation action ("Gotowe", "Zapisz").
struct MonoNavPill: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Font.manrope(13, weight: 800))
                .foregroundStyle(Tokens.Mono.onHero)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(Capsule().fill(Tokens.Mono.hero))
        }
        .buttonStyle(.plain)
    }
}

/// Muted text button used as the left navigation action ("Zamknij", "Anuluj").
struct MonoNavText: View {
    let title: String
    var emphasized = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Tokens.Font.manrope(15, weight: emphasized ? 800 : 700))
                .foregroundStyle(emphasized ? Tokens.Palette.ink : Tokens.Mono.muted)
        }
        .buttonStyle(.plain)
    }
}

/// Round outline icon button used in navigation bars (back, more).
struct MonoNavIcon: View {
    let systemName: String
    var accessibilityLabel: String = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 44, height: 44)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(accessibilityLabel))
    }
}

extension View {
    /// Inline navigation title in the mockup style (Manrope 15/800, centred).
    func monoNavigationTitle(_ title: String) -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(Tokens.Font.manrope(15, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                }
            }
    }
}

// MARK: - Form controls

/// Labelled input container: upper-case label above a 50 pt bordered field.
struct MonoField<Content: View>: View {
    let label: String
    var multiline = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            MonoLabel(text: label)
            content()
                .font(Tokens.Font.manrope(15, weight: 700))
                .foregroundStyle(Tokens.Palette.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, multiline ? 14 : 0)
                .frame(minHeight: multiline ? 84 : 50, alignment: multiline ? .topLeading : .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Tokens.Palette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Tokens.Mono.line2, lineWidth: 1)
                )
        }
    }
}

/// Toggle: 50×30 capsule, accent when on, track when off, white knob.
struct MonoToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 0)
            Capsule()
                .fill(configuration.isOn ? Tokens.Mono.accent : Tokens.Mono.track)
                .frame(width: 50, height: 30)
                .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                        .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)
                        .padding(3)
                }
                .animation(.easeOut(duration: 0.18), value: configuration.isOn)
                .onTapGesture {
                    configuration.isOn.toggle()
                    Haptics.light()
                }
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(Text(configuration.isOn ? "1" : "0"))
                .accessibilityAction { configuration.isOn.toggle() }
        }
    }
}

/// − value + stepper with outline round buttons and an italic number.
struct MonoStepper: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...10_000
    var step: Double = 1
    var unit: String = ""
    var format: String = "%.0f"

    var body: some View {
        HStack(spacing: 10) {
            roundButton("minus") { value = max(range.lowerBound, value - step) }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: format, value))
                    .font(Tokens.Font.monoNumber(20))
                    .foregroundStyle(Tokens.Palette.ink)
                    .contentTransition(.numericText())
                if !unit.isEmpty {
                    Text(unit)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
            }
            .frame(minWidth: 56)
            roundButton("plus") { value = min(range.upperBound, value + step) }
        }
    }

    private func roundButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
            Haptics.light()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Tokens.Palette.ink)
                .frame(width: 40, height: 40)
                .overlay(Circle().stroke(Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Filter chip: dark when selected, outline otherwise (36 pt).
struct MonoChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 12, weight: .bold))
                }
                Text(title).lineLimit(1)
            }
            .font(Tokens.Font.manrope(13, weight: isSelected ? 800 : 700))
            .foregroundStyle(isSelected ? Tokens.Mono.onHero : Tokens.Palette.ink)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Capsule().fill(isSelected ? Tokens.Mono.hero : Color.clear))
            .overlay(Capsule().stroke(isSelected ? Color.clear : Tokens.Mono.line2, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Segmented control: track background, selected segment is a white card.
struct MonoSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: String)]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                let isOn = option.value == selection
                Button {
                    withAnimation(Tokens.Motion.gentle) { selection = option.value }
                    Haptics.selection()
                } label: {
                    Text(option.title)
                        .font(Tokens.Font.manrope(13, weight: isOn ? 800 : 700))
                        .foregroundStyle(isOn ? Tokens.Palette.ink : Tokens.Mono.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isOn ? Tokens.Palette.surface : Color.clear)
                                .shadow(color: .black.opacity(isOn ? 0.10 : 0), radius: 1.5, y: 1)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Tokens.Mono.track)
        )
    }
}

// MARK: - Stats

/// Label + italic number + unit (light or on hero).
struct MonoStat: View {
    let label: String
    let value: String
    var unit: String = ""
    var dark = false
    var size: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MonoLabel(text: label, onHero: dark)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Tokens.Font.monoNumber(size))
                    .foregroundStyle(dark ? Tokens.Mono.onHero : Tokens.Palette.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if !unit.isEmpty {
                    Text(unit)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(dark ? Tokens.Mono.heroMuted : Tokens.Mono.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Macro pill (Białko / Węgle / Tłuszcz) for light cards or dark heroes.
struct MonoMacroChip: View {
    let label: String
    let grams: Double
    let dot: Color
    var dark = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 7, height: 7)
                Text(label)
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .textCase(.uppercase)
                    .tracking(1.1)
                    .opacity(0.75)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(grams.rounded()))")
                    .font(Tokens.Font.monoNumber(18))
                    .contentTransition(.numericText())
                Text("g").font(Tokens.Font.manrope(11, weight: 700))
            }
        }
        .foregroundStyle(dark ? Tokens.Mono.onHero : Tokens.Palette.ink)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(dark ? Tokens.Mono.heroLine : Tokens.Mono.track)
        )
    }
}

/// The standard three macro chips row.
struct MonoMacroRow: View {
    let protein: Double
    let carbs: Double
    let fat: Double
    var dark = false

    var body: some View {
        HStack(spacing: 6) {
            MonoMacroChip(
                label: L("Białko"), grams: protein, dot: dark ? Tokens.Mono.onHero : Tokens.Mono.strong, dark: dark)
            MonoMacroChip(label: L("Węgle"), grams: carbs, dot: Tokens.Mono.accent, dark: dark)
            MonoMacroChip(label: L("Tłuszcz"), grams: fat, dot: Tokens.Mono.fat, dark: dark)
        }
    }
}

// MARK: - Misc

/// Muted helper paragraph (12/600) placed under cards.
struct MonoHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
    }
}

/// Striped placeholder used where the mockups show an image slot.
struct MonoImagePlaceholder: View {
    var height: CGFloat = 180
    var label: String = ""

    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Tokens.Mono.track)
            .frame(height: height)
            .overlay(
                Label(label, systemImage: "photo")
                    .font(Tokens.Font.manrope(13, weight: 700))
                    .foregroundStyle(Tokens.Mono.muted)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Tokens.Mono.line, lineWidth: 1)
            )
    }
}
