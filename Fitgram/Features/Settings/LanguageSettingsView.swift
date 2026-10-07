import SwiftUI

/// In-app language picker. Lives inside Settings; tapping a row swaps
/// the app's language instantly — no need to leave for iOS Settings
/// and no app restart needed. The chosen language is remembered across
/// launches and overrides the system locale.
struct LanguageSettingsView: View {
    @Bindable var store: LocalizationStore
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                MonoH1(text: languageHeaderTitle, sub: languageHeaderSubtitle, kicker: languageTitle)
                languageList
                    .padding(.top, 16)
                helpHint
            }
            .padding(.horizontal, Tokens.Space.screenPadding)
            .padding(.bottom, Tokens.Space.lg)
        }
        .scrollIndicators(.hidden)
        .background(Tokens.Palette.background.ignoresSafeArea())
        .monoNavigationTitle(languageTitle)
    }

    private var languageList: some View {
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
                    MonoRowDivider(inset: 16)
                }
            }
        }
        .monoRowsCard()
    }

    private func languageRow(_ lang: LocalizationStore.SupportedLanguage) -> some View {
        let isActive = store.locale.identifier.hasPrefix(lang.code)
        return MonoRow(title: "\(lang.flag)  \(lang.nativeName)") {
            if isActive {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Tokens.Palette.ink)
            }
        }
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private var helpHint: some View {
        Text(languageHelpHint)
            .font(Tokens.Font.manrope(12, weight: 600))
            .foregroundStyle(Tokens.Mono.muted)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 6)
            .padding(.top, 10)
    }

    private var languageTitle: String {
        TL(pl: "Język", en: "Language", uk: "Мова", ru: "Язык", es: "Idioma")
    }

    private var languageHeaderTitle: String {
        TL(
            pl: "Wybierz język aplikacji",
            en: "Choose app language",
            uk: "Обери мову застосунку",
            ru: "Выбери язык приложения",
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
