import Foundation

/// Resolves a localized string for the widget process using the language
/// the user picked inside the app.
///
/// The widget runs in a separate process and `String(localized:)` honours
/// the *system* language, which can differ from the in-app switcher. The
/// app mirrors its chosen language into the shared App Group under
/// `app.language`; here we read that and look the key up through the
/// matching `.lproj` bundle so the widget stays in sync with the app.
enum WidgetLocalization {
    private static let appGroupID = "group.app.mealgram.shared"
    private static let storageKey = "app.language"
    private static let supported = ["pl", "en", "uk", "ru", "es"]

    /// Current app-selected language code, falling back to the system
    /// language and finally English.
    static func currentCode() -> String {
        if let shared = UserDefaults(suiteName: appGroupID),
            let code = shared.string(forKey: storageKey),
            supported.contains(code)
        {
            return code
        }
        for preferred in Locale.preferredLanguages {
            let primary = String(preferred.prefix(2))
            if supported.contains(primary) { return primary }
        }
        return "en"
    }

    /// Cached per-language bundles so we don't hit the filesystem on every
    /// widget body evaluation.
    private static var bundleCache: [String: Bundle] = [:]

    private static func bundle(for code: String) -> Bundle {
        if let cached = bundleCache[code] { return cached }
        let resolved: Bundle
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
            let b = Bundle(path: path)
        {
            resolved = b
        } else {
            resolved = .main
        }
        bundleCache[code] = resolved
        return resolved
    }

    /// Localized lookup honouring the app-selected language.
    static func string(_ key: String) -> String {
        bundle(for: currentCode()).localizedString(forKey: key, value: key, table: nil)
    }
}

/// Short alias mirroring the app's `L(_:)` helper.
func WL(_ key: String) -> String {
    WidgetLocalization.string(key)
}
