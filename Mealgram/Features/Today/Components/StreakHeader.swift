import SwiftUI

/// Top-of-screen greeting + streak counter. The flame only appears once
/// the user actually has a streak going so a brand-new install doesn't
/// rub a zero in the user's face.
struct StreakHeader: View {
    let greeting: LocalizedStringKey
    let displayName: String?
    let streakLength: Int
    let onTapProfile: () -> Void

    @State private var isExplanationPresented = false

    var body: some View {
        HStack(alignment: .center, spacing: Tokens.Space.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(Tokens.Font.title3)
                    .foregroundStyle(Tokens.Palette.inkMuted)
                Text(name)
                    .font(Tokens.Font.title)
                    .foregroundStyle(Tokens.Palette.ink)
            }
            Spacer()
            Button {
                isExplanationPresented = true
                Haptics.light()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: streakLength > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(streakLength > 0 ? Tokens.Palette.warning : Tokens.Palette.inkSubtle)
                    Text(String.localizedStringWithFormat(L("%lld"), streakLength))
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(streakLength > 0 ? Tokens.Palette.ink : Tokens.Palette.inkMuted)
                }
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.sm)
                .background(
                    Capsule().fill(
                        streakLength > 0
                            ? Tokens.Palette.warning.opacity(0.15)
                            : Tokens.Palette.surfaceMuted
                    )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String.localizedStringWithFormat(L("Streak %lld dni"), streakLength)))
            .accessibilityHint(Text("Stuknij, aby zobaczyć jak działa streak"))
            Button(action: onTapProfile) {
                Circle()
                    .fill(Tokens.Palette.primarySoft)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initial)
                            .font(Tokens.Font.bodyEmphasized)
                            .foregroundStyle(Tokens.Palette.primary)
                    )
            }
            .accessibilityLabel(Text("Profile"))
        }
        .sheet(isPresented: $isExplanationPresented) {
            StreakExplanationSheet(streakLength: streakLength) {
                isExplanationPresented = false
            }
            .presentationDetents([.medium])
        }
    }

    private var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return L("ty")
    }

    private var initial: String {
        if let first = displayName?.first { return String(first).uppercased() }
        return "M"
    }
}
