import Foundation

/// Usernames: 3–20 characters, lowercase latin letters, digits, "." and "_",
/// starting with a letter. Chosen once in onboarding and locked afterwards
/// (the server enforces the lock).
enum UsernamePolicy {
    static let minLength = 3
    static let maxLength = 20

    enum Problem: Equatable, Sendable {
        case tooShort
        case tooLong
        case mustStartWithLetter
        case invalidCharacters
        case doubleSeparator
        case endsWithSeparator
        case reserved
        case profanity

        var message: String {
            switch self {
            case .tooShort:
                return TL(
                    pl: "Minimum \(UsernamePolicy.minLength) znaki.",
                    en: "At least \(UsernamePolicy.minLength) characters.",
                    uk: "Мінімум \(UsernamePolicy.minLength) символи.",
                    ru: "Минимум \(UsernamePolicy.minLength) символа.",
                    es: "Mínimo \(UsernamePolicy.minLength) caracteres.")
            case .tooLong:
                return TL(
                    pl: "Maksymalnie \(UsernamePolicy.maxLength) znaków.",
                    en: "At most \(UsernamePolicy.maxLength) characters.",
                    uk: "Максимум \(UsernamePolicy.maxLength) символів.",
                    ru: "Максимум \(UsernamePolicy.maxLength) символов.",
                    es: "Máximo \(UsernamePolicy.maxLength) caracteres.")
            case .mustStartWithLetter:
                return TL(
                    pl: "Zacznij od litery.", en: "Start with a letter.", uk: "Почни з літери.", ru: "Начни с буквы.",
                    es: "Empieza con una letra.")
            case .invalidCharacters:
                return TL(
                    pl: "Tylko litery a–z, cyfry, kropka i podkreślnik.",
                    en: "Only letters a–z, digits, dot and underscore.",
                    uk: "Лише латинські літери a–z, цифри, крапка й підкреслення.",
                    ru: "Только латинские буквы a–z, цифры, точка и подчёркивание.",
                    es: "Solo letras a–z, números, punto y guion bajo.")
            case .doubleSeparator:
                return TL(
                    pl: "Bez dwóch znaków „.” lub „_” obok siebie.", en: "No two \".\" or \"_\" in a row.",
                    uk: "Без двох «.» чи «_» поспіль.", ru: "Без двух «.» или «_» подряд.",
                    es: "Sin dos \".\" o \"_\" seguidos.")
            case .endsWithSeparator:
                return TL(
                    pl: "Nie kończ kropką ani podkreślnikiem.", en: "Don't end with a dot or underscore.",
                    uk: "Не закінчуй крапкою чи підкресленням.", ru: "Не заканчивай точкой или подчёркиванием.",
                    es: "No termines con punto ni guion bajo.")
            case .reserved:
                return TL(
                    pl: "Ta nazwa jest zarezerwowana.", en: "This name is reserved.", uk: "Це ім'я зарезервоване.",
                    ru: "Это имя зарезервировано.", es: "Este nombre está reservado.")
            case .profanity:
                return TL(
                    pl: "Wybierz inną nazwę.", en: "Please pick a different name.", uk: "Обери інше ім'я.",
                    ru: "Выбери другое имя.", es: "Elige otro nombre.")
            }
        }
    }

    private static let reserved: Set<String> = [
        "fitgram", "admin", "administrator", "support", "pomoc", "help", "moderator", "mod", "official", "ola",
        "coach", "system", "root", "null", "undefined", "me", "you", "team", "staff", "apple", "google",
    ]

    /// Lowercases and drops a leading "@" and surrounding spaces — what the
    /// text field shows back to the user while they type.
    static func normalize(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasPrefix("@") { value.removeFirst() }
        return value
    }

    static func problem(for raw: String) -> Problem? {
        let name = normalize(raw)
        if name.count < minLength { return .tooShort }
        if name.count > maxLength { return .tooLong }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._")
        if !name.allSatisfy(allowed.contains) { return .invalidCharacters }
        guard let first = name.first, first.isLetter else { return .mustStartWithLetter }
        if name.contains("..") || name.contains("__") || name.contains("._") || name.contains("_.") {
            return .doubleSeparator
        }
        if name.hasSuffix(".") || name.hasSuffix("_") { return .endsWithSeparator }
        let bare = name.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "_", with: "")
        if reserved.contains(name) || reserved.contains(bare) || bare.hasPrefix("fitgram") { return .reserved }
        if PostContentPolicy.containsProfanity(
            name.replacingOccurrences(of: ".", with: " ")
                .replacingOccurrences(of: "_", with: " ")) || PostContentPolicy.containsProfanity(bare)
        {
            return .profanity
        }
        return nil
    }

    static func isValid(_ raw: String) -> Bool { problem(for: raw) == nil }

    /// Auto-generated placeholder usernames ("mg1a2b3c…") don't count as
    /// chosen — the user still gets asked to pick one.
    static func isPlaceholder(_ username: String) -> Bool {
        username.hasPrefix("mg") && username.count == 12 && username.dropFirst(2).allSatisfy(\.isHexDigit)
    }

    /// Suggestion from a display name: "Anna Kowalska" → "anna.kowalska".
    static func suggestion(from displayName: String) -> String {
        let folded = displayName.lowercased()
            .replacingOccurrences(of: "ł", with: "l")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var result = ""
        for character in folded {
            if character.isASCII, character.isLetter || character.isNumber {
                result.append(character)
            } else if character == " " || character == "." || character == "_" || character == "-" {
                if let last = result.last, last != "." { result.append(".") }
            }
        }
        while result.hasSuffix(".") { result.removeLast() }
        while let first = result.first, !first.isLetter { result.removeFirst() }
        return String(result.prefix(maxLength))
    }
}
