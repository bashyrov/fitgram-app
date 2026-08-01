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
            languageBackground
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
        .navigationTitle(Text(languageTitle))
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
                    Text(languageHeaderTitle)
                        .font(Tokens.Font.title3)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(languageHeaderSubtitle)
                        .font(Tokens.Font.footnote)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var languageBackground: some View {
        ZStack {
            Tokens.Palette.background
            Circle()
                .fill(Tokens.Palette.primarySoft.opacity(0.42))
                .frame(width: 350, height: 350)
                .blur(radius: 108)
                .offset(x: -160, y: -210)
            Circle()
                .fill(Tokens.Palette.accentSoft.opacity(0.24))
                .frame(width: 300, height: 300)
                .blur(radius: 112)
                .offset(x: 150, y: -10)
            Circle()
                .fill(Tokens.Palette.warning.opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 100)
                .offset(x: -80, y: 350)
        }
        .ignoresSafeArea()
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
            Text(languageHelpHint)
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

    private var languageTitle: String {
        TL(pl: "Język", en: "Language", uk: "Мова", ru: "Язык", es: "Idioma")
    }

    private var languageHeaderTitle: String {
        TL(
            pl: "Wybierz język aplikacji",
            en: "Choose app language",
            uk: "Виберіть мову застосунку",
            ru: "Выберите язык приложения",
            es: "Elige el idioma de la app"
        )
    }

    private var languageHeaderSubtitle: String {
        TL(
            pl: "Zmiana zachodzi od razu, bez restartu.",
            en: "The change happens instantly, without a restart.",
            uk: "Зміна застосовується одразу, без перезапуску.",
            ru: "Изменение применяется сразу, без перезапуска.",
            es: "El cambio se aplica al instante, sin reiniciar."
        )
    }

    private var languageHelpHint: String {
        TL(
            pl: "Niektóre etykiety systemowe, np. okna uprawnień, mogą pozostać w języku iOS.",
            en: "Some system labels, such as permission prompts, may remain in your iOS language.",
            uk: "Деякі системні написи, наприклад запити дозволів, можуть залишатися мовою iOS.",
            ru: "Некоторые системные надписи, например запросы разрешений, могут остаться на языке iOS.",
            es: "Algunas etiquetas del sistema, como los permisos, pueden seguir en el idioma de iOS."
        )
    }
}
