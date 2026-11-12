import Foundation

extension Locale {
    /// The language picked in the app (Settings → Język aplikacji), which can
    /// differ from the iPhone's language. Date and number format styles use
    /// the system locale unless given this one.
    static var app: Locale { Locale(identifier: LocalizationStore.currentLanguageCode()) }
}
