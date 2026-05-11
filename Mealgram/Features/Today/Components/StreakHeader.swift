import SwiftUI

/// Top-of-screen greeting + streak counter. The flame only appears once
/// the user actually has a streak going so a brand-new install doesn't
/// rub a zero in the user's face.
struct StreakHeader: View {
    let greeting: LocalizedStringKey
    let displayName: String?
    let streakLength: Int
    let onTapProfile: () -> Void

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
            if streakLength > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Tokens.Palette.warning)
                    Text("\(streakLength)")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.ink)
                }
                .padding(.horizontal, Tokens.Space.md)
                .padding(.vertical, Tokens.Space.sm)
                .background(
                    Capsule().fill(Tokens.Palette.warning.opacity(0.15))
                )
                .accessibilityLabel(Text("Streak \(streakLength) dni"))
            }
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
            .accessibilityLabel(Text("Profil"))
        }
    }

    private var name: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return String(localized: "ty")
    }

    private var initial: String {
        if let first = displayName?.first { return String(first).uppercased() }
        return "M"
    }
}
