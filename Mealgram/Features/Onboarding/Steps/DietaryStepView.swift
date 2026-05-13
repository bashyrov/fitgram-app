import SwiftUI

/// Onboarding step that lets the user pick zero or more dietary
/// preferences. Stored on the User row and consumed by the Coach
/// context once those rules ship. Skippable — no preference is a valid
/// choice, since most users don't have restrictions.
struct DietaryStepView: View {
    @Binding var selected: Set<DietaryPreference>
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            VStack(spacing: Tokens.Space.lg) {
                Spacer()
                VStack(spacing: Tokens.Space.sm) {
                    Text("Czego unikasz?")
                        .font(Tokens.Font.title)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Pomożemy dostroić sugestie. Nic nie musisz wybierać.")
                        .font(Tokens.Font.body)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Tokens.Space.xl)
                }
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                        GridItem(.flexible(), spacing: Tokens.Space.md),
                    ],
                    spacing: Tokens.Space.md
                ) {
                    ForEach(DietaryPreference.allCases) { pref in
                        chip(pref)
                    }
                }
                .padding(.horizontal, Tokens.Space.xl)
                Spacer()
                PrimaryButton(
                    title: selected.isEmpty ? "Pomiń" : "Dalej",
                    systemImage: "arrow.right",
                    action: onContinue
                )
                .padding(.horizontal, Tokens.Space.screenPadding)
            }
            .padding(.vertical, Tokens.Space.xl)
        }
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
                RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                    .fill(isOn ? Tokens.Palette.primary : Tokens.Palette.primarySoft)
            )
        }
        .buttonStyle(.plain)
    }
}
