import Foundation

/// Count + noun in the app language, with the right plural form:
/// "1 dzień / 2 dni / 5 dni", "1 день / 2 дня / 5 дней", "1 day / 2 days".
/// Polish, Ukrainian and Russian have three forms; English and Spanish two.
enum Plural {
    struct Forms {
        let one: String
        let few: String
        let many: String

        init(_ one: String, _ few: String, _ many: String) {
            self.one = one
            self.few = few
            self.many = many
        }

        init(_ one: String, _ other: String) {
            self.init(one, other, other)
        }
    }

    /// One set of forms per shipped language.
    struct Localized {
        let pl: Forms
        let en: Forms
        let uk: Forms
        let ru: Forms
        let es: Forms
    }

    enum Category: Equatable {
        case one, few, many
    }

    /// CLDR integer rules for the languages the app ships.
    static func category(_ count: Int, language: String) -> Category {
        let value = abs(count)
        let lastDigit = value % 10
        let lastTwo = value % 100
        let isFew = (2...4).contains(lastDigit) && !(12...14).contains(lastTwo)
        switch language {
        case "pl":
            if value == 1 { return .one }
            return isFew ? .few : .many
        case "uk", "ru":
            if lastDigit == 1 && lastTwo != 11 { return .one }
            return isFew ? .few : .many
        default:
            return value == 1 ? .one : .many
        }
    }

    static func word(
        _ count: Int, _ localized: Localized, language: String = LocalizationStore.currentLanguageCode()
    ) -> String {
        let forms: Forms
        switch language {
        case "pl": forms = localized.pl
        case "uk": forms = localized.uk
        case "ru": forms = localized.ru
        case "es": forms = localized.es
        default: forms = localized.en
        }
        switch category(count, language: language) {
        case .one: return forms.one
        case .few: return forms.few
        case .many: return forms.many
        }
    }

    static func dayWord(_ count: Int) -> String {
        word(
            count,
            Localized(
                pl: Forms("dzień", "dni", "dni"),
                en: Forms("day", "days"),
                uk: Forms("день", "дні", "днів"),
                ru: Forms("день", "дня", "дней"),
                es: Forms("día", "días")
            ))
    }

    static func days(_ count: Int) -> String { "\(count) \(dayWord(count))" }

    static func meals(_ count: Int) -> String {
        "\(count) "
            + word(
                count,
                Localized(
                    pl: Forms("posiłek", "posiłki", "posiłków"),
                    en: Forms("meal", "meals"),
                    uk: Forms("прийом їжі", "прийоми їжі", "прийомів їжі"),
                    ru: Forms("приём пищи", "приёма пищи", "приёмов пищи"),
                    es: Forms("comida", "comidas")
                ))
    }

    static func entries(_ count: Int) -> String {
        "\(count) "
            + word(
                count,
                Localized(
                    pl: Forms("wpis", "wpisy", "wpisów"),
                    en: Forms("entry", "entries"),
                    uk: Forms("запис", "записи", "записів"),
                    ru: Forms("запись", "записи", "записей"),
                    es: Forms("entrada", "entradas")
                ))
    }

    static func friends(_ count: Int) -> String {
        "\(count) "
            + word(
                count,
                Localized(
                    pl: Forms("znajomy", "znajomych", "znajomych"),
                    en: Forms("friend", "friends"),
                    uk: Forms("друг", "друзі", "друзів"),
                    ru: Forms("друг", "друга", "друзей"),
                    es: Forms("amigo", "amigos")
                ))
    }

    static func friendWord(_ count: Int) -> String {
        word(
            count,
            Localized(
                pl: Forms("znajomy", "znajomych", "znajomych"),
                en: Forms("friend", "friends"),
                uk: Forms("друг", "друзі", "друзів"),
                ru: Forms("друг", "друга", "друзей"),
                es: Forms("amigo", "amigos")
            ))
    }

    static func badges(_ count: Int) -> String {
        "\(count) "
            + word(
                count,
                Localized(
                    pl: Forms("odznaka", "odznaki", "odznak"),
                    en: Forms("badge", "badges"),
                    uk: Forms("відзнака", "відзнаки", "відзнак"),
                    ru: Forms("значок", "значка", "значков"),
                    es: Forms("insignia", "insignias")
                ))
    }
}
