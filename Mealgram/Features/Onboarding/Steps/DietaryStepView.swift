import SwiftUI

/// Onboarding step that lets the user pick zero or more dietary
/// preferences. Stored on the User row and consumed by the Coach
/// context once those rules ship. Skippable — no preference is a valid
/// choice, since most users don't have restrictions.
struct DietaryStepView: View {
    @Binding var selected: Set<DietaryPreference>
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: Tokens.Space.sm),
        GridItem(.flexible(), spacing: Tokens.Space.sm),
    ]

    var body: some View {
        OnboardingStepScaffold(
            title: "Czego unikasz?",
            subtitle: "We'll fine-tune our suggestions. You don't have to pick anything.",
            primaryTitle: selected.isEmpty ? "Next" : "Next",
            primarySystemImage: "arrow.right",
            onPrimary: onContinue,
            content: {
                VStack(spacing: Tokens.Space.lg) {
                    LazyVGrid(columns: columns, spacing: Tokens.Space.sm) {
                        ForEach(DietaryPreference.allCases) { pref in
                            chip(pref)
                        }
                    }
                    if selected.isEmpty {
                        emptyHint
                    }
                }
            }
        )
    }

    private var emptyHint: some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(Tokens.Palette.primary)
            Text("All good — you don't have to pick anything.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
        )
    }

    private func chip(_ pref: DietaryPreference) -> some View {
        let isOn = selected.contains(pref)
        return Button {
            if isOn {
                selected.remove(pref)
            } else {
                selected.insert(pref)
            }
            Haptics.light()
        } label: {
            VStack(spacing: Tokens.Space.sm) {
                Image(systemName: pref.symbol)
                    .font(.title2)
                    .foregroundStyle(isOn ? .white : Tokens.Palette.primary)
                Text(pref.label)
                    .font(Tokens.Font.bodyEmphasized)
                    .foregroundStyle(isOn ? .white : Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.lg)
            .background(
                RoundedRectangle(cornerRadius: Tokens.Radius.lg, style: .continuous)
                    .fill(
                        isOn
                            ? AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Tokens.Palette.primary,
                                        Tokens.Palette.primary.opacity(0.85),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            : AnyShapeStyle(Tokens.Palette.surface)
                    )
                    .shadow(
                        color: isOn
                            ? Tokens.Palette.primary.opacity(0.25)
                            : .black.opacity(0.04),
                        radius: isOn ? 12 : 8,
                        x: 0,
                        y: isOn ? 6 : 2
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
