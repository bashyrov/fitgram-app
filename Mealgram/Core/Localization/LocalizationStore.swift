import Foundation
import Observation
import ObjectiveC

/// In-app language switcher. Lets the user pick a language without
/// leaving Mealgram and applies it immediately — no app restart needed,
/// no trip to iOS Settings → App → Język.
///
/// How it works:
/// 1. The chosen language identifier is persisted in UserDefaults
///    (`app.language`) and mirrored into `AppleLanguages` so any system
///    framework that reads that key (Locale.preferredLanguages,
///    DateFormatter without explicit locale, etc.) picks it up.
/// 2. `Bundle.main` is dynamically reclassed to `PrivateLocalizedBundle`
///    which routes every `localizedString(forKey:value:table:)` lookup
///    through the chosen language's `.lproj`. This means `NSLocalizedString`,
///    `String(localized:)`, and SwiftUI `Text("key")` all return the
///    chosen language at the next render, with no app relaunch.
/// 3. The observable `locale` property changes; the root view watches
///    it and re-applies `.environment(\.locale, ...)` + bumps `.id(...)`
///    so the entire SwiftUI tree refreshes immediately.
///
/// On first launch we honour the user's iOS system language (so users
/// who downloaded with Polish system get Polish, Russian system gets
/// Russian, etc.), falling back to Polish for unsupported locales.
@MainActor
@Observable
final class LocalizationStore {
    /// Languages bundled with the app. Order matches the picker UI.
    static let supportedLanguages: [SupportedLanguage] = [
        SupportedLanguage(code: "pl", nativeName: "Polski", flag: "🇵🇱"),
        SupportedLanguage(code: "en", nativeName: "English", flag: "🇬🇧"),
        SupportedLanguage(code: "uk", nativeName: "Українська", flag: "🇺🇦"),
        SupportedLanguage(code: "ru", nativeName: "Русский", flag: "🇷🇺"),
        SupportedLanguage(code: "es", nativeName: "Español", flag: "🇪🇸"),
    ]

    struct SupportedLanguage: Identifiable, Hashable, Sendable {
        let code: String
        let nativeName: String
        let flag: String
        var id: String { code }
    }

    private static let storageKey = "app.language"

    private(set) var locale: Locale

    init() {
        let code = LocalizationStore.resolveInitialLanguage()
        self.locale = Locale(identifier: code)
        // Apply the bundle swap on init so any early String(localized:)
        // calls during DI graph construction see the chosen language.
        Bundle.setLanguage(code)
        // Mirror into AppleLanguages so any third-party framework that
        // reads the system preferred list also follows the user's pick.
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
    }

    /// Switches the app language immediately. After this returns, the
    /// observing SwiftUI views re-render with the new strings.
    func setLanguage(_ code: String) {
        guard LocalizationStore.supportedLanguages.contains(where: { $0.code == code }) else {
            return
        }
        UserDefaults.standard.set(code, forKey: LocalizationStore.storageKey)
        UserDefaults.standard.set([code], forKey: "AppleLanguages")
        Bundle.setLanguage(code)
        locale = Locale(identifier: code)
    }

    /// Returns either the user's saved choice or — on first launch —
    /// the best match between iOS preferred languages and our supported
    /// list. Falls back to Polish (the development language).
    private static func resolveInitialLanguage() -> String {
        if let saved = UserDefaults.standard.string(forKey: storageKey),
            supportedLanguages.contains(where: { $0.code == saved }) {
            return saved
        }
        let supportedCodes = supportedLanguages.map(\.code)
        for preferred in Locale.preferredLanguages {
            let primary = String(preferred.prefix(2))
            if supportedCodes.contains(primary) {
                return primary
            }
        }
        return "pl"
    }
}

// MARK: - Bundle language swap

/// Bundle subclass that re-routes localization lookups to a private
/// child bundle pointing at the chosen language's `.lproj`. Installed
/// via `object_setClass` so the change is transparent to all callers
/// of `Bundle.main.localizedString(forKey:value:table:)` — including
/// `NSLocalizedString`, `String(localized:)`, and SwiftUI Text.
private final class PrivateLocalizedBundle: Bundle, @unchecked Sendable {
    override func localizedString(
        forKey key: String,
        value: String?,
        table tableName: String?
    ) -> String {
        if let inner = objc_getAssociatedObject(self, &Bundle.localizedBundleKey) as? Bundle {
            return inner.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

extension Bundle {
    fileprivate static var localizedBundleKey: UInt8 = 0

    /// Swaps `Bundle.main` to a private subclass that resolves every
    /// localized lookup through the requested language's `.lproj`.
    /// Idempotent — calling repeatedly with different languages just
    /// updates the inner bundle.
    static func setLanguage(_ language: String) {
        DispatchQueue.once {
            object_setClass(Bundle.main, PrivateLocalizedBundle.self)
        }
        let inner: Bundle? = {
            if let path = Bundle.main.path(forResource: language, ofType: "lproj") {
                return Bundle(path: path)
            }
            return nil
        }()
        objc_setAssociatedObject(
            Bundle.main,
            &localizedBundleKey,
            inner,
            .OBJC_ASSOCIATION_RETAIN_NONATOMIC
        )
    }
}

private extension DispatchQueue {
    private static var onceTracker = Set<String>()
    private static let onceLock = NSLock()

    /// Runs the block exactly once across the lifetime of the process.
    /// We swap `Bundle.main`'s class only once — re-running
    /// `object_setClass` with the same class is harmless but pointless.
    static func once(file: String = #file, line: Int = #line, block: () -> Void) {
        let token = "\(file):\(line)"
        onceLock.lock()
        defer { onceLock.unlock() }
        guard !onceTracker.contains(token) else { return }
        onceTracker.insert(token)
        block()
    }
}
