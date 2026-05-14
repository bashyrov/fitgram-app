import SwiftUI

/// Editorial top strip — serif greeting, eyebrow date, flame chip and
/// avatar all sit on one shared baseline. The greeting itself becomes
/// the visual anchor (large serif) rather than the streak.
struct StreakHeader: View {
    let greeting: LocalizedStringKey
    let displayName: String?
    let streakLength: Int
    let onTapProfile: () -> Void

    @State private var isExplanationPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.sm) {
            topRow
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(greeting)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(name + ".")
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Tokens.Palette.primary)
                    .italic()
            }
            .lineLimit(2)
            .minimumScaleFactor(0.6)
        }
        .sheet(isPresented: $isExplanationPresented) {
            StreakExplanationSheet(streakLength: streakLength) {
                isExplanationPresented = false
            }
            .presentationDetents([.medium])
        }
    }

    private var topRow: some View {
        HStack(spacing: Tokens.Space.sm) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Tokens.Palette.primary)
                    .frame(width: 6, height: 6)
                Text(today)
                    .eyebrowStyle()
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            streakChip
            avatarButton
        }
    }

    private var streakChip: some View {
        Button {
            isExplanationPresented = true
            Haptics.light()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: streakLength > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(streakLength > 0 ? Tokens.Palette.warning : Tokens.Palette.inkSubtle)
                Text("\(streakLength)")
                    .font(.system(size: 13, weight: .heavy, design: .default))
                    .foregroundStyle(streakLength > 0 ? Tokens.Palette.ink : Tokens.Palette.inkMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .overlay(
                Capsule().strokeBorder(Tokens.Palette.separator, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("Streak \(streakLength) dni"))
    }

    private var avatarButton: some View {
        Button(action: onTapProfile) {
            Circle()
                .fill(Tokens.Palette.ink)
                .frame(width: 36, height: 36)
                .overlay(
                    Text(initial)
                        .font(.system(size: 14, weight: .heavy, design: .serif))
                        .foregroundStyle(Tokens.Palette.background)
                )
        }
        .accessibilityLabel(Text("Profil"))
    }

    private var today: String {
        let date = Date()
        return date.formatted(.dateTime.weekday(.wide).day().month(.wide))
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
