import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct AppearanceSettingsView: View {
    @AppStorage(AppAccentPalette.storageKey) private var accentRaw = AppAccentPalette.rose.rawValue
    @AppStorage(AppIconChoice.storageKey) private var iconRaw = AppIconChoice.primary.rawValue

    @State private var iconError: String?
    @State private var isChangingIcon = false

    private var selectedAccent: AppAccentPalette {
        let palette = AppAccentPalette(rawValue: accentRaw) ?? .rose
        return palette.isSelectable ? palette : .rose
    }

    private var selectedIcon: AppIconChoice {
        AppIconChoice(rawValue: iconRaw) ?? .primary
    }

    var body: some View {
        ZStack {
            ScreenBackground(mood: .calm)
            ScrollView {
                LazyVStack(spacing: Tokens.Space.lg) {
                    hero
                    paletteSection
                    iconSection
                }
                .padding(.horizontal, Tokens.Space.screenPadding)
                .padding(.vertical, Tokens.Space.lg)
                .id(accentRaw)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(errorTitle, isPresented: Binding(get: { iconError != nil }, set: { if !$0 { iconError = nil } })) {
            Button(okTitle, role: .cancel) {}
        } message: {
            Text(iconError ?? "")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: Tokens.Space.xs) {
                    Text(heroTitle)
                        .font(Tokens.Font.title2)
                        .foregroundStyle(Tokens.Palette.ink)
                    Text(heroSubtitle)
                        .font(Tokens.Font.callout)
                        .foregroundStyle(Tokens.Palette.inkMuted)
                }
                Spacer()
                iconPreview(for: selectedIcon, size: 62)
            }
            HStack(spacing: Tokens.Space.sm) {
                ForEach(AppAccentPalette.selectableCases) { palette in
                    Circle()
                        .fill(palette.primary)
                        .overlay(Circle().stroke(Tokens.Palette.warmWhite.opacity(0.55), lineWidth: 1))
                        .frame(width: palette == selectedAccent ? 34 : 26, height: palette == selectedAccent ? 34 : 26)
                        .animation(Tokens.Motion.gentle, value: selectedAccent)
                }
            }
        }
        .padding(Tokens.Space.lg)
        .frostedGlass(cornerRadius: 30, fillOpacity: 0.76, borderOpacity: 0.00, glowOpacity: 0.12)
    }

    private var paletteSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(paletteTitle, symbol: "paintpalette.fill")
                ForEach(AppAccentPalette.selectableCases) { palette in
                    Button {
                        withAnimation(Tokens.Motion.gentle) {
                            accentRaw = palette.rawValue
                        }
                        Haptics.light()
                    } label: {
                        HStack(spacing: Tokens.Space.md) {
                            palettePreview(palette)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(palette.title)
                                    .font(Tokens.Font.bodyEmphasized)
                                    .foregroundStyle(Tokens.Palette.ink)
                                Text(palette.subtitle)
                                    .font(Tokens.Font.caption)
                                    .foregroundStyle(Tokens.Palette.inkMuted)
                            }
                            Spacer()
                            selectionMark(isSelected: palette == selectedAccent)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    if palette.id != AppAccentPalette.selectableCases.last?.id {
                        separator
                    }
                }
            }
        }
    }

    private var iconSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Tokens.Space.md) {
                sectionHeader(iconTitle, symbol: "app.badge.fill")
                Text(iconSubtitle)
                    .font(Tokens.Font.footnote)
                    .foregroundStyle(Tokens.Palette.inkMuted)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 96), spacing: Tokens.Space.md)], spacing: Tokens.Space.md
                ) {
                    ForEach(AppIconChoice.allCases) { choice in
                        iconOptionButton(choice)
                    }
                }
            }
        }
    }

    private func iconOptionButton(_ choice: AppIconChoice) -> some View {
        let isSelected = choice == selectedIcon
        return Button {
            Task { await applyIcon(choice) }
        } label: {
            VStack(spacing: Tokens.Space.sm) {
                iconPreview(for: choice, size: 64)
                Text(choice.title)
                    .font(Tokens.Font.caption.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                selectionMark(isSelected: isSelected)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Tokens.Space.md)
            .frostedGlass(
                cornerRadius: 22,
                fillOpacity: isSelected ? 0.82 : 0.60,
                borderOpacity: 0.00,
                glowOpacity: isSelected ? 0.10 : 0.04
            )
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(isChangingIcon)
    }

    private func sectionHeader(_ text: String, symbol: String) -> some View {
        HStack(spacing: Tokens.Space.sm) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Tokens.Palette.primarySoft))
            Text(text)
                .font(Tokens.Font.headline)
                .foregroundStyle(Tokens.Palette.ink)
            Spacer()
        }
    }

    private var separator: some View {
        Rectangle()
            .fill(Tokens.Palette.separator)
            .frame(height: 0.5)
            .padding(.leading, 62)
    }

    private func palettePreview(_ palette: AppAccentPalette) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [palette.background, palette.surface, palette.primary.opacity(0.50)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.primary.opacity(0.35), lineWidth: 1)
                }
            Circle()
                .fill(palette.primary)
                .frame(width: 18, height: 18)
                .offset(x: 12, y: 12)
        }
    }

    private func iconPreview(for choice: AppIconChoice, size: CGFloat) -> some View {
        Image(choice.previewAssetName)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: choice.shadowColor.opacity(0.24), radius: 14, y: 8)
    }

    @ViewBuilder
    private func selectionMark(isSelected: Bool) -> some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Tokens.Palette.primary)
        } else {
            Circle()
                .stroke(Tokens.Palette.separator, lineWidth: 0.35)
                .frame(width: 20, height: 20)
        }
    }

    @MainActor
    private func applyIcon(_ choice: AppIconChoice) async {
        guard choice != selectedIcon else { return }
        isChangingIcon = true
        defer { isChangingIcon = false }

        #if canImport(UIKit)
        guard UIApplication.shared.supportsAlternateIcons else {
            iconError = unsupportedIconMessage
            return
        }

        do {
            try await UIApplication.shared.setAlternateIconName(choice.alternateIconName)
            iconRaw = choice.rawValue
            Haptics.success()
        } catch {
            iconError = failedIconMessage
        }
        #else
        iconError = unsupportedIconMessage
        #endif
    }

    private var title: String {
        TL(pl: "Wygląd", en: "Appearance", uk: "Вигляд", ru: "Внешний вид", es: "Apariencia")
    }

    private var heroTitle: String {
        TL(
            pl: "Dopasuj Fitgram", en: "Tune Fitgram", uk: "Налаштуй Fitgram", ru: "Настрой Fitgram",
            es: "Personaliza Fitgram")
    }

    private var heroSubtitle: String {
        TL(
            pl: "Wybierz jasny lub ciemny motyw oraz ikonę na ekranie iPhone'a.",
            en: "Choose a light or dark theme and iPhone Home Screen icon.",
            uk: "Обери світлу або темну тему й іконку на екрані iPhone.",
            ru: "Выбери светлую или тёмную тему и иконку на экране iPhone.",
            es: "Elige un tema claro u oscuro y el icono del iPhone.")
    }

    private var paletteTitle: String {
        TL(pl: "Motyw aplikacji", en: "App theme", uk: "Тема застосунку", ru: "Тема приложения", es: "Tema de la app")
    }

    private var iconTitle: String {
        TL(
            pl: "Ikona aplikacji", en: "App icon", uk: "Іконка застосунку", ru: "Иконка приложения",
            es: "Icono de la app")
    }

    private var iconSubtitle: String {
        TL(
            pl: "iOS może pokazać krótkie potwierdzenie po zmianie ikony.",
            en: "iOS may show a short confirmation after changing the icon.",
            uk: "iOS може показати коротке підтвердження після зміни іконки.",
            ru: "iOS может показать короткое подтверждение после смены иконки.",
            es: "iOS puede mostrar una breve confirmación tras cambiar el icono.")
    }

    private var errorTitle: String {
        TL(
            pl: "Nie udało się zmienić ikony", en: "Could not change icon", uk: "Не вдалося змінити іконку",
            ru: "Не удалось сменить иконку", es: "No se pudo cambiar el icono")
    }

    private var unsupportedIconMessage: String {
        TL(
            pl: "To urządzenie nie obsługuje alternatywnych ikon.", en: "This device does not support alternate icons.",
            uk: "Цей пристрій не підтримує альтернативні іконки.",
            ru: "Это устройство не поддерживает альтернативные иконки.",
            es: "Este dispositivo no admite iconos alternativos.")
    }

    private var failedIconMessage: String {
        TL(
            pl: "Spróbuj ponownie za chwilę.", en: "Try again in a moment.", uk: "Спробуй ще раз трохи пізніше.",
            ru: "Попробуй еще раз чуть позже.", es: "Inténtalo de nuevo en un momento.")
    }

    private var okTitle: String {
        TL(pl: "OK", en: "OK", uk: "OK", ru: "OK", es: "OK")
    }
}

enum AppIconChoice: String, CaseIterable, Identifiable {
    static let storageKey = "preferences.appIcon"

    case primary
    case graphiteLime
    case graphiteLimeInverted
    case oceanNight
    case oceanNightLight
    case oceanDay
    case citrusWhiteSoft
    case daylightLime
    case porcelainCoral
    case matchaCeramic
    case nordicBerry

    var id: String { rawValue }

    var alternateIconName: String? {
        switch self {
        case .primary: return nil
        case .graphiteLime: return "AppIconGraphiteLime"
        case .graphiteLimeInverted: return "AppIconGraphiteLimeInverted"
        case .oceanNight: return "AppIconOceanNight"
        case .oceanNightLight: return "AppIconOceanNightLight"
        case .oceanDay: return "AppIconOceanDay"
        case .citrusWhiteSoft: return "AppIconCitrusWhiteSoft"
        case .daylightLime: return "AppIconDaylightLime"
        case .porcelainCoral: return "AppIconPorcelainCoral"
        case .matchaCeramic: return "AppIconMatchaCeramic"
        case .nordicBerry: return "AppIconNordicBerry"
        }
    }

    var title: String {
        switch self {
        case .primary:
            return TL(
                pl: "Citrus White", en: "Citrus White", uk: "Citrus White", ru: "Citrus White", es: "Citrus White")
        case .graphiteLime:
            return TL(
                pl: "Graphite Lime", en: "Graphite Lime", uk: "Graphite Lime", ru: "Graphite Lime",
                es: "Graphite Lime")
        case .graphiteLimeInverted:
            return TL(
                pl: "Lime Graphite", en: "Lime Graphite", uk: "Lime Graphite", ru: "Lime Graphite",
                es: "Lime Graphite")
        case .oceanNight:
            return TL(pl: "Ocean Night", en: "Ocean Night", uk: "Ocean Night", ru: "Ocean Night", es: "Ocean Night")
        case .oceanNightLight:
            return TL(
                pl: "Ocean Light", en: "Ocean Light", uk: "Ocean Light", ru: "Ocean Light", es: "Ocean Light")
        case .oceanDay:
            return TL(pl: "Ocean Day", en: "Ocean Day", uk: "Ocean Day", ru: "Ocean Day", es: "Ocean Day")
        case .citrusWhiteSoft:
            return TL(
                pl: "Citrus Glow", en: "Citrus Glow", uk: "Citrus Glow", ru: "Citrus Glow", es: "Citrus Glow")
        case .daylightLime:
            return TL(
                pl: "Daylight Lime", en: "Daylight Lime", uk: "Daylight Lime", ru: "Daylight Lime", es: "Daylight Lime")
        case .porcelainCoral:
            return TL(
                pl: "Porcelain Coral", en: "Porcelain Coral", uk: "Porcelain Coral", ru: "Porcelain Coral",
                es: "Porcelain Coral")
        case .matchaCeramic:
            return TL(
                pl: "Matcha Ceramic", en: "Matcha Ceramic", uk: "Matcha Ceramic", ru: "Matcha Ceramic",
                es: "Matcha Ceramic")
        case .nordicBerry:
            return TL(
                pl: "Nordic Berry", en: "Nordic Berry", uk: "Nordic Berry", ru: "Nordic Berry", es: "Nordic Berry")
        }
    }

    var previewAssetName: String {
        switch self {
        case .primary: return "AppIconPreviewCitrusWhite"
        case .graphiteLime: return "AppIconPreviewGraphiteLime"
        case .graphiteLimeInverted: return "AppIconPreviewGraphiteLimeInverted"
        case .oceanNight: return "AppIconPreviewOceanNight"
        case .oceanNightLight: return "AppIconPreviewOceanNightLight"
        case .oceanDay: return "AppIconPreviewOceanDay"
        case .citrusWhiteSoft: return "AppIconPreviewCitrusWhiteSoft"
        case .daylightLime: return "AppIconPreviewDaylightLime"
        case .porcelainCoral: return "AppIconPreviewPorcelainCoral"
        case .matchaCeramic: return "AppIconPreviewMatchaCeramic"
        case .nordicBerry: return "AppIconPreviewNordicBerry"
        }
    }

    var shadowColor: Color {
        switch self {
        case .primary: return Color(red: 0.90, green: 0.46, blue: 0.18)
        case .graphiteLime: return Color(red: 0.72, green: 1.00, blue: 0.33)
        case .graphiteLimeInverted: return Color(red: 0.22, green: 0.23, blue: 0.22)
        case .oceanNight: return Color(red: 0.31, green: 0.74, blue: 0.90)
        case .oceanNightLight: return Color(red: 0.40, green: 0.68, blue: 0.82)
        case .oceanDay: return Color(red: 0.39, green: 0.67, blue: 0.80)
        case .citrusWhiteSoft: return Color(red: 0.98, green: 0.53, blue: 0.28)
        case .daylightLime: return Color(red: 0.33, green: 0.50, blue: 0.22)
        case .porcelainCoral: return Color(red: 0.55, green: 0.66, blue: 0.83)
        case .matchaCeramic: return Color(red: 0.42, green: 0.56, blue: 0.32)
        case .nordicBerry: return Color(red: 0.58, green: 0.18, blue: 0.38)
        }
    }
}
