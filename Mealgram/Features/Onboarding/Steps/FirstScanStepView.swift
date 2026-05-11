import SwiftUI

/// Mock first-scan demo. Real camera lands in Milestone 1.5 — this teaches
/// the gesture and shows what the result screen will look like.
struct FirstScanStepView: View {
    let onContinue: () -> Void

    @State private var hasScanned = false

    var body: some View {
        OnboardingStepScaffold(
            title: hasScanned ? "Tak właśnie to działa" : "Zrób (fałszywe) zdjęcie",
            subtitle: hasScanned
                ? "Tak zobaczysz wyniki po realnym skanie. Wszystko da się poprawić."
                : "Spróbuj naszego skanera w trybie demo. Bez aparatu, bez kalorii — tylko klimat.",
            primaryTitle: hasScanned ? "Świetnie, dalej" : "Pomiń demo",
            primarySystemImage: "arrow.right",
            onPrimary: onContinue,
            content: {
                if hasScanned {
                    MockScanResultView()
                } else {
                    DemoScanButton {
                        withAnimation(Tokens.Motion.gentle) { hasScanned = true }
                    }
                }
            }
        )
    }
}

private struct DemoScanButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: Tokens.Space.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Tokens.Radius.xl, style: .continuous)
                        .fill(Tokens.Palette.primarySoft)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 96, weight: .light))
                        .foregroundStyle(Tokens.Palette.primary)
                }
                .frame(height: 260)
                .mealgramShadow(Tokens.Shadow.float)

                Text("Stuknij, żeby zobaczyć demo")
                    .font(Tokens.Font.callout)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct MockScanResultView: View {
    var body: some View {
        Card(elevation: Tokens.Shadow.float) {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                HStack {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(Tokens.Palette.primary)
                    Text("Sałatka z kurczakiem")
                        .font(Tokens.Font.headline)
                    Spacer()
                    Text("~420 kcal")
                        .font(Tokens.Font.bodyEmphasized)
                        .foregroundStyle(Tokens.Palette.primary)
                }
                Divider().background(Tokens.Palette.separator)
                macroLine(label: "Białko", value: "32 g")
                macroLine(label: "Węgle", value: "18 g")
                macroLine(label: "Tłuszcz", value: "22 g")
            }
        }
    }

    private func macroLine(label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        HStack {
            Text(label)
                .font(Tokens.Font.body)
                .foregroundStyle(Tokens.Palette.inkMuted)
            Spacer()
            Text(value)
                .font(Tokens.Font.bodyEmphasized)
                .foregroundStyle(Tokens.Palette.ink)
        }
    }
}
