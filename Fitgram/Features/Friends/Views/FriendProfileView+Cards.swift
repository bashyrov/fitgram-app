import SwiftUI

// Lock and empty-state cards of the profile sheet.
extension FriendProfileView {
    var restrictedCard: some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: "lock.fill", style: .dark, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(
                    TL(
                        pl: "Profil zamknięty", en: "Private profile", uk: "Закритий профіль", ru: "Закрытый профиль",
                        es: "Perfil privado")
                )
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                Text(
                    connection == .friend
                        ? TL(
                            pl: "Ta osoba nikomu nie pokazuje szczegółów profilu.",
                            en: "This person doesn't show profile details to anyone.",
                            uk: "Ця людина нікому не показує деталі профілю.",
                            ru: "Этот человек никому не показывает детали профиля.",
                            es: "Esta persona no muestra los detalles de su perfil.")
                        : TL(
                            pl: "Statystyki widzą tylko znajomi. Wyślij zaproszenie, żeby zobaczyć więcej.",
                            en: "Only friends see the stats. Send a request to see more.",
                            uk: "Статистику бачать лише друзі. Надішли запит, щоб побачити більше.",
                            ru: "Статистику видят только друзья. Отправь заявку, чтобы увидеть больше.",
                            es: "Solo los amigos ven las estadísticas. Envía una solicitud para ver más.")
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    var privacyHint: some View {
        HStack(spacing: 10) {
            MonoIconBox(systemName: "lock", style: .track, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Ten profil nie udostępnia szczegółów"))
                    .font(Tokens.Font.manrope(14, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl: "Zależy od ustawień prywatności znajomego.",
                        en: "Depends on your friend's privacy settings.",
                        uk: "Залежить від налаштувань приватності друга.",
                        ru: "Зависит от настроек приватности друга.",
                        es: "Depende de la configuración de privacidad de tu amigo."
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    func placeholder(
        symbol: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            MonoIconBox(systemName: symbol, style: .track, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                Text(subtitle)
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }
}
