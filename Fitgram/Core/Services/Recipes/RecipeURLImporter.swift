import Foundation
import OSLog

/// Fetches a URL, scans the HTML for any `<script type="application/ld+json">`
/// blocks, parses them as schema.org JSON-LD, and pulls out the first
/// node tagged `@type: "Recipe"`. Returns a populated `RecipeDraft` ready
/// to hand to `RecipeFormSheet`.
///
/// Polish food blogs (kwestiasmaku.com, hreceptu.pl) and most modern
/// recipe sites publish JSON-LD by default — no LLM needed.
struct RecipeURLImporter {
    enum ImportError: Error, Equatable {
        case invalidURL
        case fetchFailed(String)
        case noRecipeFound
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func `import`(from urlString: String) async throws -> RecipeDraft {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else {
            throw ImportError.invalidURL
        }
        var request = URLRequest(url: url)
        // Many sites Cloudflare-block the default URLSession UA; spoof a
        // common one so we don't have to ship a per-site allowlist.
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ImportError.fetchFailed("HTTP \(http.statusCode)")
        }
        guard let html = String(data: data, encoding: .utf8) else {
            throw ImportError.fetchFailed("Non-UTF8 body")
        }
        return try parse(html: html, sourceURL: url)
    }

    /// Public for tests — accepts raw HTML, returns the parsed draft.
    func parse(html: String, sourceURL: URL?) throws -> RecipeDraft {
        for jsonString in Self.extractJSONLDBlocks(from: html) {
            if let draft = Self.draftIfRecipe(jsonString: jsonString, sourceURL: sourceURL) {
                return draft
            }
        }
        throw ImportError.noRecipeFound
    }

    // MARK: - JSON-LD extraction

    static func extractJSONLDBlocks(from html: String) -> [String] {
        let pattern =
            #"<script[^>]*type\s*=\s*['""]application/ld\+json['""][^>]*>([\s\S]*?)</script>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return []
        }
        let range = NSRange(html.startIndex..., in: html)
        return regex.matches(in: html, options: [], range: range).compactMap { match in
            guard match.numberOfRanges >= 2, let range = Range(match.range(at: 1), in: html) else {
                return nil
            }
            return String(html[range])
        }
    }

    /// Walks the decoded JSON tree (which may be a single object, an array,
    /// or wrapped in `@graph`) looking for the first node whose `@type`
    /// contains "Recipe".
    static func draftIfRecipe(jsonString: String, sourceURL: URL?) -> RecipeDraft? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        for node in flatten(json) {
            if isRecipe(node), let draft = draft(from: node, sourceURL: sourceURL) {
                return draft
            }
        }
        return nil
    }

    private static func flatten(_ value: Any) -> [[String: Any]] {
        var out: [[String: Any]] = []
        if let dict = value as? [String: Any] {
            out.append(dict)
            if let graph = dict["@graph"] as? [Any] {
                graph.forEach { out.append(contentsOf: flatten($0)) }
            }
        } else if let array = value as? [Any] {
            array.forEach { out.append(contentsOf: flatten($0)) }
        }
        return out
    }

    private static func isRecipe(_ node: [String: Any]) -> Bool {
        if let type = node["@type"] as? String {
            return type.contains("Recipe")
        }
        if let array = node["@type"] as? [Any] {
            return array.contains(where: { ($0 as? String)?.contains("Recipe") ?? false })
        }
        return false
    }

    private static func draft(from node: [String: Any], sourceURL: URL?) -> RecipeDraft? {
        guard let title = (node["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !title.isEmpty
        else { return nil }

        let summary = (node["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let servings = parseServings(node["recipeYield"])
        let ingredients = stringList(from: node["recipeIngredient"])
        let instructions = parseInstructions(node["recipeInstructions"])
        let nutrition = node["nutrition"] as? [String: Any]
        return RecipeDraft(
            title: title,
            summary: summary?.isEmpty == false ? summary : nil,
            servings: servings,
            ingredients: ingredients,
            instructions: instructions,
            caloriesPerServing: nutrition.flatMap { parseNumber($0["calories"]) },
            proteinPerServing: nutrition.flatMap { parseNumber($0["proteinContent"]) },
            carbsPerServing: nutrition.flatMap { parseNumber($0["carbohydrateContent"]) },
            fatPerServing: nutrition.flatMap { parseNumber($0["fatContent"]) },
            prepMinutes: parseISO8601Minutes(node["prepTime"]),
            cookMinutes: parseISO8601Minutes(node["cookTime"]) ?? parseISO8601Minutes(node["totalTime"])
        )
    }

    private static func stringList(from value: Any?) -> [String] {
        if let array = value as? [String] {
            return array.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        }
        return []
    }

    private static func parseInstructions(_ value: Any?) -> [String] {
        // schema.org allows recipeInstructions to be a string, a string
        // array, or an array of HowToStep objects. Handle all three.
        if let string = value as? String {
            return
                string
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        if let array = value as? [Any] {
            return array.compactMap { entry in
                if let text = entry as? String { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard let dict = entry as? [String: Any] else { return nil }
                let text = (dict["text"] as? String) ?? (dict["name"] as? String)
                return text?.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty }
        }
        return []
    }

    private static func parseServings(_ value: Any?) -> Int {
        if let number = value as? Int { return max(1, number) }
        if let string = value as? String {
            let digits = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .joined()
            return max(1, Int(digits) ?? 2)
        }
        if let array = value as? [Any], let first = array.first {
            return parseServings(first)
        }
        return 2
    }

    /// Parses an ISO-8601 duration (`PT30M`, `PT1H15M`, `PT2H`) into a
    /// minute count. Public for tests.
    static func parseISO8601Minutes(_ value: Any?) -> Int? {
        guard let string = value as? String,
            !string.isEmpty,
            string.hasPrefix("PT") || string.hasPrefix("P")
        else { return nil }
        let body = string.replacingOccurrences(of: "PT", with: "").replacingOccurrences(of: "P", with: "")
        var minutes = 0
        let hoursMatch = body.range(of: #"(\d+)H"#, options: .regularExpression)
        let minutesMatch = body.range(of: #"(\d+)M"#, options: .regularExpression)
        if let hoursMatch {
            let hoursString = body[hoursMatch].dropLast()
            minutes += (Int(hoursString) ?? 0) * 60
        }
        if let minutesMatch {
            let minutesString = body[minutesMatch].dropLast()
            minutes += Int(minutesString) ?? 0
        }
        return minutes > 0 ? minutes : nil
    }

    private static func parseNumber(_ value: Any?) -> Double? {
        if let number = value as? Double { return number }
        if let int = value as? Int { return Double(int) }
        if let string = value as? String {
            let cleaned = string.components(separatedBy: CharacterSet(charactersIn: "0123456789.,").inverted)
                .joined()
                .replacingOccurrences(of: ",", with: ".")
            return Double(cleaned)
        }
        return nil
    }
}
