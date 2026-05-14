import Foundation

/// Why the upgrade prompt is being shown. Drives the headline + body
/// copy on `UpgradeSheet` so the framing matches the feature the user
/// actually wanted, instead of a generic "upgrade now" pitch. Also
/// great for analytics — each kind has a stable rawValue.
enum PaywallTrigger: String, Equatable, Sendable {
    case photoScanQuota = "photo_scan_quota"
    case barcodeScanQuota = "barcode_scan_quota"
    case voiceEntryQuota = "voice_entry_quota"
    case coachDebriefQuota = "coach_debrief_quota"
    case favoritesUnavailable = "favorites_unavailable"
    case customGoalsCap = "custom_goals_cap"
    case friendsCap = "friends_cap"
    case recipesCap = "recipes_cap"
    case exportCsv = "export_csv"
    case exportZip = "export_zip"
    case themePicker = "theme_picker"
    case iCloudSync = "icloud_sync"
    case goalTracking = "goal_tracking"
    case manual = "manual"
}

extension PaywallTrigger {
    /// Polish copy paired with the trigger. UI just consumes; localizing
    /// to EN/UK later means widening to a localized key, not touching
    /// every call site.
    struct Copy {
        let headline: String
        let body: String
        let badge: String?
    }

    var copy: Copy {
        switch self {
        case .photoScanQuota:
            return Copy(
                headline: "Wykorzystałeś skany na ten tydzień",
                body: "Premium daje nieograniczone skany zdjęć + dokładniejszy Gemini Pro AI. 7 dni za darmo.",
                badge: "Skanowanie AI"
            )
        case .barcodeScanQuota:
            return Copy(
                headline: "Limit kodów wyczerpany",
                body: "Z Premium skanujesz kody bez limitu — i dostajesz całą Bazę Otwartą żywności.",
                badge: "Kody"
            )
        case .voiceEntryQuota:
            return Copy(
                headline: "Limit nagrań głosowych wyczerpany",
                body: "Premium odblokowuje nieograniczone wpisy głosem + szybkie parsowanie po polsku.",
                badge: "Głos"
            )
        case .coachDebriefQuota:
            return Copy(
                headline: "Ola podsumowała Twój tydzień",
                body: "W Premium Ola pisze podsumowania kiedy chcesz — codziennie albo na żądanie.",
                badge: "AI Coach"
            )
        case .favoritesUnavailable:
            return Copy(
                headline: "Moje przepisy — limit 5 na free",
                body: "Zapisuj swoje stałe pozycje, dodawaj jednym tapnięciem. Zaoszczędź minuty dziennie.",
                badge: "Ulubione"
            )
        case .customGoalsCap:
            return Copy(
                headline: "Więcej celów = Premium",
                body: "W bezpłatnej wersji jeden aktywny cel. Premium pozwala mieć trzy jednocześnie.",
                badge: "Cele"
            )
        case .friendsCap:
            return Copy(
                headline: "Dodaj więcej znajomych w Premium",
                body: "Bezpłatne konto wspiera 3 znajomych. Premium otwiera nieograniczoną grupę.",
                badge: "Społeczność"
            )
        case .recipesCap:
            return Copy(
                headline: "Pełna książka przepisów = Premium",
                body: "Bezpłatnie 5 przepisów. Premium odblokowuje nieograniczoną książkę + import z URL.",
                badge: "Przepisy"
            )
        case .exportCsv, .exportZip:
            return Copy(
                headline: "Eksport do CSV / ZIP — Premium",
                body: "W bezpłatnym koncie zostawiamy eksport JSON. Premium dodaje CSV (dla Excela) i pełny pakiet ZIP.",
                badge: "Eksport"
            )
        case .themePicker:
            return Copy(
                headline: "Wybór motywu — Premium",
                body: "Tryb ciemny, jasny albo automatyczny. Premium pozwala ustawić sztywno.",
                badge: "Motyw"
            )
        case .iCloudSync:
            return Copy(
                headline: "Synchronizacja przez iCloud — Premium",
                body: "Dane między telefonem a iPadem zawsze świeże. Premium włącza iCloud sync.",
                badge: "Sync"
            )
        case .goalTracking:
            return Copy(
                headline: "Śledzenie celu — Premium",
                body: "Codzienna waga, wykres trendu i przypomnienie. Premium odblokowuje pełne śledzenie postępu.",
                badge: "Cel"
            )
        case .manual:
            return Copy(
                headline: "Wypróbuj Mealgram Premium",
                body: "7 dni za darmo. Pełne AI, nieograniczone skany, AI Coach, eksporty.",
                badge: nil
            )
        }
    }
}
