import Foundation

/// Client-side checks for post text: length, allowed characters, links and
/// a profanity list (PL / EN / UK / RU / ES). The server re-checks lengths;
/// the word list lives here so it can be tuned without a migration.
enum PostContentPolicy {
    enum Field: Sendable {
        case title
        case body
    }

    enum Violation: Equatable, Sendable {
        case titleTooShort
        case titleTooLong
        case bodyTooLong
        case titleMultiline
        case tooManyLines
        case forbiddenCharacters
        case repeatedCharacters
        case links
        case profanity

        var message: String {
            switch self {
            case .titleTooShort:
                return TL(
                    pl: "Tytuł musi mieć co najmniej \(PostLimits.titleMin) znaki.",
                    en: "The title needs at least \(PostLimits.titleMin) characters.",
                    uk: "Заголовок має містити щонайменше \(PostLimits.titleMin) символи.",
                    ru: "В заголовке нужно минимум \(PostLimits.titleMin) символа.",
                    es: "El título necesita al menos \(PostLimits.titleMin) caracteres.")
            case .titleTooLong:
                return TL(
                    pl: "Tytuł może mieć maksymalnie \(PostLimits.titleMax) znaków.",
                    en: "The title can have at most \(PostLimits.titleMax) characters.",
                    uk: "Заголовок — максимум \(PostLimits.titleMax) символів.",
                    ru: "Заголовок — максимум \(PostLimits.titleMax) символов.",
                    es: "El título admite como máximo \(PostLimits.titleMax) caracteres.")
            case .bodyTooLong:
                return TL(
                    pl: "Opis może mieć maksymalnie \(PostLimits.bodyMax) znaków.",
                    en: "The description can have at most \(PostLimits.bodyMax) characters.",
                    uk: "Опис — максимум \(PostLimits.bodyMax) символів.",
                    ru: "Описание — максимум \(PostLimits.bodyMax) символов.",
                    es: "La descripción admite como máximo \(PostLimits.bodyMax) caracteres.")
            case .titleMultiline:
                return TL(
                    pl: "Tytuł musi mieścić się w jednej linii.", en: "The title must be a single line.",
                    uk: "Заголовок має бути в один рядок.", ru: "Заголовок должен быть в одну строку.",
                    es: "El título debe ocupar una sola línea.")
            case .tooManyLines:
                return TL(
                    pl: "Za dużo pustych linii w opisie.", en: "Too many line breaks in the description.",
                    uk: "Забагато порожніх рядків в описі.", ru: "Слишком много переносов строк в описании.",
                    es: "Demasiados saltos de línea en la descripción.")
            case .forbiddenCharacters:
                return TL(
                    pl: "Tekst zawiera niedozwolone znaki.", en: "The text contains characters that aren't allowed.",
                    uk: "Текст містить недозволені символи.", ru: "В тексте есть недопустимые символы.",
                    es: "El texto contiene caracteres no permitidos.")
            case .repeatedCharacters:
                return TL(
                    pl: "Za dużo powtórzonych znaków z rzędu.", en: "Too many repeated characters in a row.",
                    uk: "Забагато однакових символів підряд.", ru: "Слишком много одинаковых символов подряд.",
                    es: "Demasiados caracteres repetidos seguidos.")
            case .links:
                return TL(
                    pl: "Linki w postach są niedozwolone.", en: "Links aren't allowed in posts.",
                    uk: "Посилання в постах заборонені.", ru: "Ссылки в постах запрещены.",
                    es: "No se permiten enlaces en las publicaciones.")
            case .profanity:
                return TL(
                    pl: "Bez wulgaryzmów — napisz to inaczej.", en: "No profanity — try saying it differently.",
                    uk: "Без лайки — спробуй сказати інакше.", ru: "Без мата — попробуй сказать иначе.",
                    es: "Sin groserías: dilo de otra manera.")
            }
        }
    }

    static let maxBodyLines = 12
    static let maxRepeatedRun = 6

    /// Every problem with a title + body pair, in display order. Empty means
    /// the post can be published.
    static func violations(title: String, body: String) -> [Violation] {
        var result: [Violation] = []
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.count < PostLimits.titleMin { result.append(.titleTooShort) }
        if trimmedTitle.count > PostLimits.titleMax { result.append(.titleTooLong) }
        if trimmedTitle.contains(where: \.isNewline) { result.append(.titleMultiline) }
        if trimmedBody.count > PostLimits.bodyMax { result.append(.bodyTooLong) }
        if trimmedBody.filter(\.isNewline).count > maxBodyLines { result.append(.tooManyLines) }
        let combined = trimmedTitle + "\n" + trimmedBody
        if hasForbiddenCharacters(combined) { result.append(.forbiddenCharacters) }
        if hasLongRepeatedRun(combined) { result.append(.repeatedCharacters) }
        if containsLink(combined) { result.append(.links) }
        if containsProfanity(combined) { result.append(.profanity) }
        return result
    }

    // MARK: - Characters

    /// Letters of any script, digits, punctuation, symbols (incl. emoji) and
    /// spaces are fine. Control / format / private-use characters and
    /// "zalgo" stacks of combining marks are not.
    static func hasForbiddenCharacters(_ text: String) -> Bool {
        var combiningRun = 0
        for scalar in text.unicodeScalars {
            let category = scalar.properties.generalCategory
            switch category {
            case .control:
                if scalar != "\n" { return true }
                combiningRun = 0
            case .format:
                // Zero-width joiner / variation selectors build emoji.
                if scalar.value != 0x200D, scalar.value != 0xFE0F { return true }
            case .privateUse, .surrogate, .unassigned, .lineSeparator, .paragraphSeparator:
                return true
            case .nonspacingMark, .enclosingMark, .spacingMark:
                combiningRun += 1
                if combiningRun > 2 { return true }
            default:
                combiningRun = 0
            }
        }
        return false
    }

    static func hasLongRepeatedRun(_ text: String) -> Bool {
        var previous: Character?
        var run = 0
        for character in text where !character.isWhitespace {
            if character == previous {
                run += 1
                if run > maxRepeatedRun { return true }
            } else {
                previous = character
                run = 1
            }
        }
        return false
    }

    static func containsLink(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if lowered.contains("http://") || lowered.contains("https://") || lowered.contains("www.") { return true }
        let pattern = #"\b[a-z0-9-]{2,}\.(com|pl|net|org|io|ru|ua|es|eu|me|ly|gg|tv|app|xyz|info|shop)\b"#
        return lowered.range(of: pattern, options: .regularExpression) != nil
    }

    // MARK: - Profanity

    /// Matched anywhere inside a normalised word.
    private static let anywhere: [String] = [
        // Polish
        "kurw", "chuj", "pierdol", "pierdal", "jebac", "jeban", "jebie", "jebn", "zajeb", "wyjeb", "pojeb",
        "przejeb", "odjeb", "rozjeb", "skurwy", "skurwi", "pizd", "kutas", "cipsk", "dziwk", "zjeb", "huj",
        "sukinsyn",
        // English
        "fuck", "shit", "bitch", "cunt", "asshol", "motherf", "nigg", "fagot", "whore", "slut", "bastard",
        "dickhead", "wanker",
        // Russian / Ukrainian (folded: й → и, ё → е)
        "хуи", "хуе", "хуя", "пизд", "заеб", "выеб", "проеб", "наеб", "доеб", "отъеб", "бляд", "блят",
        "мудак", "мудил", "пидор", "пидар", "залуп", "гандон", "шлюх", "дроч", "пізд",
        // Spanish
        "mierd", "cabron", "joder", "gilipoll", "pendej", "chinga", "culero",
    ]

    /// Only flagged when the word starts with them — they hide inside
    /// innocent words otherwise ("computadora", "тебе", "небалансированный").
    private static let prefixes: [String] = [
        "puta", "puto", "verga", "cwel", "ебат", "ебан", "ебал", "ебло", "ебу", "уеб", "сука", "суки", "хер",
        "педик",
    ]

    /// Whole words only.
    private static let wholeWords: Set<String> = ["dick", "cock", "fag", "бля", "еба", "ебл"]

    /// Real words that start with a flagged prefix.
    private static let allowList: Set<String> = [
        "херсон", "херсона", "херсоні", "херсоне", "херес", "херувим", "сукин", "сукно", "scunthorpe", "shitake",
        "verganza",
    ]

    static func containsProfanity(_ text: String) -> Bool {
        let anywhereStems = anywhere.map(normalize)
        let prefixStems = prefixes.map(normalize)
        let whole = Set(wholeWords.map(normalize))
        let allowed = Set(allowList.map(normalize))
        for candidate in words(in: text).flatMap(variants) {
            let word = normalize(candidate)
            guard !word.isEmpty, !allowed.contains(word) else { continue }
            if whole.contains(word) { return true }
            if anywhereStems.contains(where: { word.contains($0) }) { return true }
            if prefixStems.contains(where: { word.hasPrefix($0) }) { return true }
        }
        return false
    }

    /// Whitespace-separated tokens with in-word punctuation dropped, so
    /// "k.u.r.w.a" can't slip through. Leetspeak symbols are kept.
    private static func words(in text: String) -> [String] {
        let keep: Set<Character> = ["@", "$", "!", "*"]
        return text.split(whereSeparator: { $0.isWhitespace }).map { token in
            String(token.filter { $0.isLetter || $0.isNumber || keep.contains($0) })
        }
    }

    /// "f*ck" / "sh*t": try the masked letter as each vowel.
    private static func variants(of word: String) -> [String] {
        guard word.contains("*") else { return [word] }
        return ["a", "e", "i", "o", "u"].map { word.replacingOccurrences(of: "*", with: $0) }
    }

    /// Lowercase, strip diacritics, undo leetspeak and collapse repeated
    /// letters ("fuuuck" → "fuck").
    static func normalize(_ word: String) -> String {
        let leet: [Character: Character] = [
            "0": "o", "1": "i", "3": "e", "4": "a", "5": "s", "7": "t", "@": "a", "$": "s", "!": "i",
        ]
        let folded = word.lowercased()
            .replacingOccurrences(of: "ł", with: "l")
            .folding(options: [.diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        var output = ""
        var previous: Character?
        for character in folded {
            let mapped = leet[character] ?? character
            guard mapped.isLetter else { continue }
            if mapped == previous { continue }
            output.append(mapped)
            previous = mapped
        }
        return output
    }
}
