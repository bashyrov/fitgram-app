import SwiftUI

// swiftlint:disable file_length

enum AddMealQuota: Equatable {
    case unlimited
    case limited(used: Int, cap: Int)

    var label: String? {
        switch self {
        case .unlimited:
            return nil
        case .limited(let used, let cap):
            return "\(max(0, cap - used))/\(cap)"
        }
    }

    var isExhausted: Bool {
        if case .limited(let used, let cap) = self { return used >= cap }
        return false
    }
}

struct AddMealMiniActionCard: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let quota: AddMealQuota
    let action: () -> Void

    /// Mockup `mode(...)`: 22 pt card, outline icon box 38, Archivo title, muted copy.
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    MonoIconBox(systemName: quota.isExhausted ? "lock.fill" : icon, style: .outline, size: 38)
                    Spacer(minLength: 0)
                    AddMealQuotaBadge(quota: quota, isProminent: false)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(Tokens.Font.archivo(size: 16, weight: 800, width: 115))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(subtitle)
                        .font(Tokens.Font.manrope(12, weight: 600))
                        .foregroundStyle(Tokens.Mono.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Tokens.Palette.surface)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        quota.isExhausted ? Tokens.Palette.warning.opacity(0.42) : Tokens.Mono.line,
                        lineWidth: 1
                    )
            }
            .opacity(quota.isExhausted ? 0.78 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.pressable)
    }
}

struct AddMealCompactPill: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    let quota: AddMealQuota
    let action: () -> Void

    /// Mockup `pill(...)`: 48 pt outline capsule, icon 16 + 14/800 title.
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: quota.isExhausted ? "lock.fill" : icon)
                    .font(.system(size: 15, weight: .semibold))
                Text(title)
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .lineLimit(1)
                AddMealQuotaBadge(quota: quota, isProminent: false)
            }
            .foregroundStyle(Tokens.Palette.ink)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .overlay(Capsule().stroke(Tokens.Mono.line2, lineWidth: 1))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
    }
}

struct AddHubStageModifier: ViewModifier {
    let isVisible: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 20)
            .scaleEffect(isVisible ? 1 : 0.985)
            .animation(Tokens.Motion.gentle.delay(Double(index) * 0.055), value: isVisible)
    }
}

extension View {
    func addHubStage(isVisible: Bool, index: Int) -> some View {
        modifier(AddHubStageModifier(isVisible: isVisible, index: index))
    }
}

struct AddMealQuotaBadge: View {
    let quota: AddMealQuota
    let isProminent: Bool
    var foreground: Color?
    var background: Color?

    var body: some View {
        if let label = quota.label {
            HStack(spacing: 4) {
                if quota.isExhausted {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 9, weight: .bold))
                }
                Text(label)
                    .font(Tokens.Font.manrope(11, weight: 800))
            }
            .foregroundStyle(foreground ?? (isProminent ? .white : Tokens.Palette.inkMuted))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(
                        background ?? (isProminent ? .white.opacity(0.18) : Tokens.Mono.track))
            )
        }
    }
}

// MARK: - Design D add-meal flow blocks

enum AddFlowCopy {
    static var fillWithAI: String {
        TL(pl: "Uzupełnij AI", en: "Fill with AI", uk: "Доповнити AI", ru: "Дополнить AI", es: "Completar con IA")
    }
}
// Shared by the scan / voice / manual / database / barcode confirmation sheets. Each mirrors one
// helper of the mockup library (`nav`, `total_hero`, `name_field`, `portion_card`, `ingr_list`).

/// `nav(title, 'Zamknij', right)` for sheets without a navigation stack: muted text on the left,
/// centred 15/800 title, optional trailing control (e.g. `MonoNavPill`).
struct AddFlowNavBar<Trailing: View>: View {
    let title: String
    var leftTitle: String = L("Zamknij")
    let onLeft: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        leftTitle: String = L("Zamknij"),
        onLeft: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.title = title
        self.leftTitle = leftTitle
        self.onLeft = onLeft
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack {
                MonoNavText(title: leftTitle, action: onLeft)
                    .frame(height: 44)
                Spacer(minLength: 0)
            }
            .frame(width: 84)
            Text(title)
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
            HStack {
                Spacer(minLength: 0)
                trailing()
            }
            .frame(width: 84)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .frame(minHeight: 52)
    }
}

extension AddFlowNavBar where Trailing == EmptyView {
    init(title: String, leftTitle: String = L("Zamknij"), onLeft: @escaping () -> Void) {
        self.init(title: title, leftTitle: leftTitle, onLeft: onLeft) { EmptyView() }
    }
}

/// `total_hero(...)`: hi icon box + caption, 60 pt italic kcal and the macro chips on the dark hero.
struct AddFlowTotalHero<Badge: View>: View {
    let icon: String
    let caption: String
    let kcal: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    @ViewBuilder var badge: () -> Badge

    init(
        icon: String,
        caption: String,
        kcal: Double,
        protein: Double,
        carbs: Double,
        fat: Double,
        @ViewBuilder badge: @escaping () -> Badge
    ) {
        self.icon = icon
        self.caption = caption
        self.kcal = kcal
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.badge = badge
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: icon, style: .hi, size: 40)
                Text(caption)
                    .font(Tokens.Font.manrope(11, weight: 800))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Tokens.Mono.heroMuted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                badge()
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "\(Int(kcal.rounded()))")
                    .font(Tokens.Font.monoNumber(60))
                    .foregroundStyle(Tokens.Mono.onHero)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .contentTransition(.numericText())
                Text("kcal")
                    .font(Tokens.Font.manrope(16, weight: 800))
                    .foregroundStyle(Tokens.Mono.heroMuted)
            }
            MonoMacroRow(protein: protein, carbs: carbs, fat: fat, dark: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Mono.Radius.hero, style: .continuous)
                .fill(Tokens.Mono.hero)
        )
        .accessibilityElement(children: .combine)
    }
}

extension AddFlowTotalHero where Badge == EmptyView {
    init(icon: String, caption: String, kcal: Double, protein: Double, carbs: Double, fat: Double) {
        self.init(icon: icon, caption: caption, kcal: kcal, protein: protein, carbs: carbs, fat: fat) {
            EmptyView()
        }
    }
}

/// Dark 48 pt "✦ Odśwież AI" button used next to name fields (mockup `name_field`).
struct AddFlowAIButton: View {
    var title: String = L("Odśwież AI")
    let isLoading: Bool
    var remaining: Int?
    var showsQuota = true
    var height: CGFloat = 48
    var fullWidth = false
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Tokens.Mono.hi)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(title)
                    .font(Tokens.Font.manrope(12, weight: 800))
                    .lineLimit(1)
                if showsQuota {
                    Text(quotaLabel)
                        .font(Tokens.Font.manrope(10, weight: 800))
                        .foregroundStyle(remaining == 0 ? Tokens.Mono.danger : Tokens.Mono.heroMuted)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .overlay(Capsule().stroke(Tokens.Mono.heroLine, lineWidth: 1))
                        .accessibilityLabel(Text(quotaAccessibilityLabel))
                }
            }
            .foregroundStyle(Tokens.Mono.hi)
            .padding(.horizontal, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: fullWidth ? height / 2 : 14, style: .continuous)
                    .fill(Tokens.Mono.hero)
            )
        }
        .buttonStyle(.pressable)
        .disabled(isDisabled)
        .opacity(isDisabled && !isLoading ? 0.55 : 1)
    }

    private var quotaLabel: String {
        guard let remaining else { return "∞" }
        return String.localizedStringWithFormat(L("%lld left"), remaining)
    }

    private var quotaAccessibilityLabel: String {
        guard let remaining else { return L("Unlimited AI requests") }
        return String.localizedStringWithFormat(L("%lld AI requests left today"), remaining)
    }
}

/// `name_field(...)`: card with a label, a 48 pt bordered input and a trailing action (AI button).
struct AddFlowNameCard<Field: View, Action: View>: View {
    let label: String
    @ViewBuilder var field: () -> Field
    @ViewBuilder var action: () -> Action

    init(label: String, @ViewBuilder field: @escaping () -> Field, @ViewBuilder action: @escaping () -> Action) {
        self.label = label
        self.field = field
        self.action = action
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MonoLabel(text: label)
            HStack(spacing: 8) {
                field()
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Tokens.Mono.line2, lineWidth: 1)
                    )
                action()
            }
        }
        .monoCard(padding: 16)
    }
}

/// `portion_card(...)`: "PORCJA" label + italic grams, slider with range labels and a hint.
struct AddFlowPortionCard: View {
    @Binding var grams: Double
    var range: ClosedRange<Double> = 10...1500
    var step: Double = 5
    var label: String = L("Porcja")
    var note: String?
    var hint: String? = L("Dopasuj wagę przed dodaniem")

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                MonoLabel(text: label)
                Spacer(minLength: 0)
                if let note {
                    Text(note)
                        .font(Tokens.Font.manrope(12, weight: 700))
                        .foregroundStyle(Tokens.Mono.muted)
                }
                Text(Self.gramsText(grams))
                    .font(Tokens.Font.monoNumber(22))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                    .contentTransition(.numericText())
            }
            VStack(spacing: 6) {
                Slider(value: $grams, in: range, step: step)
                    .tint(Tokens.Mono.strong)
                HStack {
                    Text(Self.gramsText(range.lowerBound))
                    Spacer()
                    Text(Self.gramsText(range.upperBound))
                }
                .font(Tokens.Font.manrope(11, weight: 700))
                .foregroundStyle(Tokens.Mono.muted)
            }
            if let hint {
                Text(hint)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .monoCard(padding: 16)
    }

    static func gramsText(_ grams: Double) -> String {
        String.localizedStringWithFormat(L("%lld g"), Int(grams.rounded()))
    }
}

/// `ingr_list(...)`: section header with count + muted subtitle, then one card holding the
/// ingredient rows and a footer with actions ("Dodaj składnik" / "Uzupełnij AI").
struct AddFlowIngredientsSection<Rows: View, Footer: View>: View {
    let title: String
    let count: Int
    var sub: String?
    @ViewBuilder var rows: () -> Rows
    @ViewBuilder var footer: () -> Footer

    init(
        title: String,
        count: Int,
        sub: String? = nil,
        @ViewBuilder rows: @escaping () -> Rows,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.title = title
        self.count = count
        self.sub = sub
        self.rows = rows
        self.footer = footer
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            MonoSectionHeader(title: title) {
                MonoLabel(text: "\(count)")
            }
            .padding(.horizontal, 6)
            .padding(.top, 22 - Tokens.Space.lg)
            if let sub {
                Text(sub)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
                    .padding(.top, 8)
            }
            VStack(spacing: 0) {
                rows()
                HStack(spacing: 8) {
                    footer()
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
            .monoRowsCard()
            .padding(.top, sub == nil ? 12 : 10)
        }
    }
}

/// `ingredient(...)`: red minus, name + kcal, grams slider with the current weight underneath.
struct AddFlowIngredientRow<Name: View, Accessory: View>: View {
    var showsDivider: Bool
    let kcal: Double
    @Binding var grams: Double
    var range: ClosedRange<Double>
    var step: Double
    var onRemove: (() -> Void)?
    var detail: String?
    @ViewBuilder var name: () -> Name
    @ViewBuilder var accessory: () -> Accessory

    init(
        showsDivider: Bool = false,
        kcal: Double,
        grams: Binding<Double>,
        range: ClosedRange<Double> = 10...800,
        step: Double = 5,
        onRemove: (() -> Void)? = nil,
        detail: String? = nil,
        @ViewBuilder name: @escaping () -> Name,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.showsDivider = showsDivider
        self.kcal = kcal
        self._grams = grams
        self.range = range
        self.step = step
        self.onRemove = onRemove
        self.detail = detail
        self.name = name
        self.accessory = accessory
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider {
                Rectangle()
                    .fill(Tokens.Mono.line)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
            HStack(spacing: 10) {
                if let onRemove {
                    Button {
                        onRemove()
                        Haptics.selection()
                    } label: {
                        Image(systemName: "minus")
                            .font(.system(size: 15, weight: .heavy))
                            .foregroundStyle(Tokens.Mono.danger)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        Text(
                            TL(
                                pl: "Usuń składnik", en: "Remove ingredient", uk: "Видалити інгредієнт",
                                ru: "Удалить ингредиент", es: "Quitar ingrediente"
                            )
                        )
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        name()
                            .font(Tokens.Font.manrope(14, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        accessory()
                        Text(String.localizedStringWithFormat(L("%lld kcal"), Int(kcal.rounded())))
                            .font(Tokens.Font.manrope(13, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Slider(value: $grams, in: range, step: step)
                            .tint(Tokens.Mono.strong)
                        Text(gramsCaption)
                            .font(Tokens.Font.manrope(11, weight: 700))
                            .foregroundStyle(Tokens.Mono.muted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

extension AddFlowIngredientRow {
    fileprivate var gramsCaption: String {
        let gramsText = AddFlowPortionCard.gramsText(grams)
        guard let detail, !detail.isEmpty else { return gramsText }
        return gramsText + " · " + detail
    }
}

extension AddFlowIngredientRow where Accessory == EmptyView {
    init(
        showsDivider: Bool = false,
        kcal: Double,
        grams: Binding<Double>,
        range: ClosedRange<Double> = 10...800,
        step: Double = 5,
        onRemove: (() -> Void)? = nil,
        detail: String? = nil,
        @ViewBuilder name: @escaping () -> Name
    ) {
        self.init(
            showsDivider: showsDivider, kcal: kcal, grams: grams, range: range, step: step, onRemove: onRemove,
            detail: detail, name: name, accessory: { EmptyView() }
        )
    }
}
