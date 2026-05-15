import SwiftUI

/// In-app language picker. Lives inside Settings; tapping a row swaps
/// the app's language instantly — no need to leave for iOS Settings
/// and no app restart needed. The chosen language is remembered across
/// launches and overrides the system locale.
struct LanguageSettingsView: View {
    @Bindable var store: LocalizationStore
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Tokens.Palette.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: Tokens.Space.lg) {
                    headerCard
                    languageList
                    helpHint
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
            }
        }
        .navigationTitle(Text("Język"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        Card(elevation: Tokens.Shadow.float) {
            HStack(spacing: Tokens.Space.md) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Tokens.Palette.primary, Tokens.Palette.accent],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                        .shadow(color: Tokens.Palette.primary.opacity(0.35), radius: 10, y: 4)
                    Image(systemName: "globe")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Wybierz język aplikacji")
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text("Zmiana zachodzi od razu, bez restartu.")
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var languageList: some View {
        Card {
            VStack(spacing: 0) {
                ForEach(Array(LocalizationStore.supportedLanguages.enumerated()), id: \.element.id) { idx, lang in
                    Button {
                        Haptics.selection()
                        store.setLanguage(lang.code)
                    } label: {
                        languageRow(lang)
                    }
                    .buttonStyle(.plain)
                    if idx < LocalizationStore.supportedLanguages.count - 1 {
                        Rectangle()
                            .fill(Tokens.Palette.separator)
                            .frame(height: 0.5)
                            .padding(.leading, 56)
                    }
                }
            }
        }
    }

    private func languageRow(_ lang: LocalizationStore.SupportedLanguage) -> some View {
        let isActive = store.locale.identifier.hasPrefix(lang.code)
        return HStack(spacing: Tokens.Space.md) {
            Text(lang.flag)
                .font(.system(size: 30))
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(lang.nativeName)
                    .font(Tokens.Font.body)
                    .foregroundStyle(Tokens.Palette.ink)
                Text(lang.code.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Tokens.Palette.inkMuted)
            }
            Spacer()
            if isActive {
                ZStack {
                    Circle()
                        .fill(Tokens.Palette.primary)
                        .frame(width: 22, height: 22)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Circle()
                    .stroke(Tokens.Palette.separator, lineWidth: 1.5)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.vertical, Tokens.Space.sm)
        .padding(.horizontal, Tokens.Space.sm)
        .contentShape(Rectangle())
    }

    private var helpHint: some View {
        HStack(alignment: .top, spacing: Tokens.Space.sm) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
            Text("Niektóre etykiety systemowe (np. okna z prośbą o pozwolenie) będą po polsku do momentu restartu telefonu.")
                .font(Tokens.Font.footnote)
                .foregroundStyle(Tokens.Palette.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Tokens.Space.md)
        .background(
            RoundedRectangle(cornerRadius: Tokens.Radius.md, style: .continuous)
                .fill(Tokens.Palette.primarySoft)
        )
    }
}
