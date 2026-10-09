import SwiftUI

// Secondary cards on the Znajomi tab: username prompt, Premium upsell and
// the empty feed.
extension FriendsRootView {
    var usernameCard: some View {
        Button {
            isUsernamePickerPresented = true
        } label: {
            MonoRow(
                icon: "at",
                iconStyle: .accent,
                title: TL(
                    pl: "Wybierz swój username", en: "Pick your username", uk: "Обери свій username",
                    ru: "Выбери свой username", es: "Elige tu usuario"),
                sub: TL(
                    pl: "Dzięki niemu znajomi znajdą Cię w wyszukiwarce.", en: "So friends can find you in search.",
                    uk: "Так друзі знайдуть тебе в пошуку.", ru: "Так друзья найдут тебя в поиске.",
                    es: "Así tus amigos te encontrarán.")
            ) {
                MonoChevron()
            }
        }
        .buttonStyle(.plain)
        .monoRowsCard()
    }

    var premiumCard: some View {
        HStack(alignment: .top, spacing: 12) {
            PremiumMark(height: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 8) {
                Text(
                    TL(
                        pl: "Posty piszą użytkownicy Premium", en: "Posts are written by Premium members",
                        uk: "Пости пишуть користувачі Premium", ru: "Посты пишут пользователи Premium",
                        es: "Las publicaciones son de Premium")
                )
                .font(Tokens.Font.manrope(15, weight: 800))
                .foregroundStyle(Tokens.Palette.ink)
                Text(
                    TL(
                        pl:
                            "Czytać i lajkować możesz za darmo. "
                            + "Z Premium dodasz do \(PostLimits.dailyMax) postów dziennie — ze zdjęciem i makro.",
                        en:
                            "Reading and liking is free. With Premium you can share up to \(PostLimits.dailyMax) posts a day — "
                            + "with photos and macros.",
                        uk:
                            "Читати й лайкати можна безкоштовно. З Premium — до \(PostLimits.dailyMax) постів на день з фото й макро.",
                        ru:
                            "Читать и лайкать можно бесплатно. С Premium — до \(PostLimits.dailyMax) постов в день с фото и макро.",
                        es:
                            "Leer y dar me gusta es gratis. Con Premium publicas hasta \(PostLimits.dailyMax) al día, con fotos y macros."
                    )
                )
                .font(Tokens.Font.manrope(12, weight: 600))
                .foregroundStyle(Tokens.Mono.muted)
                .fixedSize(horizontal: false, vertical: true)
                MonoButton(
                    title: TL(
                        pl: "Odblokuj posty", en: "Unlock posts", uk: "Розблокувати пости",
                        ru: "Открыть посты", es: "Desbloquear publicaciones"),
                    kind: .dark, icon: "sparkles", height: 40, fullWidth: false
                ) {
                    paywallCoordinator.present(.socialPosts)
                }
            }
            Spacer(minLength: 0)
        }
        .monoCard(padding: 16)
    }

    var emptyStateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                MonoIconBox(systemName: "text.bubble", style: .track, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        TL(
                            pl: "Jeszcze bez postów", en: "No posts yet", uk: "Поки без постів", ru: "Пока без постов",
                            es: "Aún no hay publicaciones")
                    )
                    .font(Tokens.Font.manrope(15, weight: 800))
                    .foregroundStyle(Tokens.Palette.ink)
                    Text(
                        state.friends.isEmpty
                            ? TL(
                                pl: "Dodaj znajomych, żeby widzieć ich posty.",
                                en: "Add friends to see their posts.", uk: "Додай друзів, щоб бачити їхні пости.",
                                ru: "Добавь друзей, чтобы видеть их посты.",
                                es: "Añade amigos para ver sus publicaciones.")
                            : TL(
                                pl: "Znajomi jeszcze nic nie napisali. Zacznij pierwszy!",
                                en: "Your friends haven't posted yet. Be the first!",
                                uk: "Друзі ще нічого не написали. Почни першим!",
                                ru: "Друзья ещё ничего не написали. Начни первым!",
                                es: "Tus amigos aún no publicaron. ¡Sé el primero!")
                    )
                    .font(Tokens.Font.manrope(12, weight: 600))
                    .foregroundStyle(Tokens.Mono.muted)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            if state.friends.isEmpty {
                MonoButton(title: L("Dodaj znajomego"), kind: .dark, icon: "plus", height: 46) {
                    isHubPresented = true
                }
            }
        }
        .monoCard(padding: 16)
    }

}
