import SwiftUI

enum AddMealQuota: Equatable {
    case unlimited
    case daily(used: Int, cap: Int)

    var label: String? {
        switch self {
        case .unlimited:
            return nil
        case .daily(let used, let cap):
            return "\(max(0, cap - used))/\(cap)"
        }
    }

    var isExhausted: Bool {
        if case .daily(let used, let cap) = self { return used >= cap }
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

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack(alignment: .top) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Tokens.Mono.track)
                        Image(systemName: icon)
                            .font(Tokens.Font.manrope(22, weight: 800))
                            .foregroundStyle(Tokens.Palette.ink)
                    }
                    .frame(width: 52, height: 52)

                    Spacer(minLength: 0)
                    AddMealQuotaBadge(quota: quota, isProminent: false)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(Tokens.Font.manrope(18, weight: 800))
                        .foregroundStyle(Tokens.Palette.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text(subtitle)
                        .font(Tokens.Font.caption)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                HStack {
                    Text(quota.isExhausted ? "Pro" : "Otwórz")
                        .font(Tokens.Font.manrope(12, weight: 800))
                    Spacer(minLength: 0)
                    Image(systemName: quota.isExhausted ? "lock.fill" : "arrow.up.right")
                        .font(.system(size: 12, weight: .black))
                }
                .foregroundStyle(quota.isExhausted ? Tokens.Palette.warning : Tokens.Palette.ink)
            }
            .padding(Tokens.Space.md)
            .frame(maxWidth: .infinity, minHeight: 166, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Tokens.Palette.surface.opacity(0.82))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(
                        quota.isExhausted ? Tokens.Palette.warning.opacity(0.42) : Tokens.Mono.line,
                        lineWidth: 1
                    )
            }
            .opacity(quota.isExhausted ? 0.78 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                Image(systemName: quota.isExhausted ? "lock.fill" : icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(tint.opacity(0.14)))
                Text(title)
                    .font(Tokens.Font.footnote.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                AddMealQuotaBadge(quota: quota, isProminent: false)
            }
            .padding(.horizontal, Tokens.Space.md)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(Capsule().fill(Tokens.Palette.surface.opacity(0.78)))
            .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.35))
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
                        background ?? (isProminent ? .white.opacity(0.18) : Tokens.Palette.surfaceMuted.opacity(0.88)))
            )
        }
    }
}
