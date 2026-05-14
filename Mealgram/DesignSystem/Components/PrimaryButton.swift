import SwiftUI

/// Editorial primary CTA — solid ink-coloured pill that flips to coral
/// on press, with a tight inset shadow. Sharp typography. The shape is
/// intentionally minimal: this is the single most important call-to-
/// action on every screen, so it doesn't compete with anything else.
struct PrimaryButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var environmentEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(Tokens.Palette.background)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Tokens.Palette.background)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.ink)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .opacity(effectiveEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!effectiveEnabled || isLoading)
        .accessibilityAddTraits(.isButton)
    }

    private var effectiveEnabled: Bool { isEnabled && environmentEnabled }
}

/// Accent CTA — same shape but in coral. Use when you want emphasis on
/// "premium" / "upgrade" / "important next step" rather than the
/// default-confirm primary.
struct AccentButton: View {
    let title: LocalizedStringKey
    var systemImage: String?
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.isEnabled) private var environmentEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Tokens.Space.sm) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(Tokens.Palette.primary)
            )
            .contentShape(RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous))
            .opacity(effectiveEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!effectiveEnabled || isLoading)
    }

    private var effectiveEnabled: Bool { isEnabled && environmentEnabled }
}

#Preview("Primary") {
    VStack(spacing: Tokens.Space.lg) {
        PrimaryButton(title: "Dalej", systemImage: "arrow.right") {}
        AccentButton(title: "Wypróbuj Premium", systemImage: "sparkles") {}
        PrimaryButton(title: "Wyłączony", isEnabled: false) {}
    }
    .padding(Tokens.Space.xl)
    .background(Tokens.Palette.background)
}
