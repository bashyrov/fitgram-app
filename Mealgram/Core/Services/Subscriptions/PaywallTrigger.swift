import Foundation

/// Why the upgrade prompt is being shown. Drives the headline + body
/// copy on `UpgradeSheet` so the framing matches the feature the user
/// actually wanted, instead of a generic "upgrade now" pitch. Also
/// great for analytics — each kind has a stable rawValue.
enum PaywallTrigger: String, Equatable, Sendable {
    case photoScanQuota = "photo_scan_quota"
    case barcodeScanQuota = "barcode_scan_quota"
    case voiceEntryQuota = "voice_entry_quota"
    case mealAIRefreshQuota = "meal_ai_refresh_quota"
    case productNutritionQuota = "product_nutrition_quota"
    case olaChefQuota = "ola_chef_quota"
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
                headline: L("Dzienny limit AI wykorzystany"),
                body: L(
                    "W bezpłatnej wersji masz 3 zapytania AI dziennie. Pro odblokowuje pełne skanowanie i 7 dni próbne."
                ),
                badge: L("Skanowanie AI")
            )
        case .barcodeScanQuota:
            return Copy(
                headline: L("Dzienny limit AI wykorzystany"),
                body: L("W bezpłatnej wersji masz 3 zapytania AI dziennie. Pro daje więcej przestrzeni na testy."),
                badge: L("Kody")
            )
        case .voiceEntryQuota:
            return Copy(
                headline: L("Dzienny limit AI wykorzystany"),
                body: L("W bezpłatnej wersji możesz zapisać 3 posiłki AI dziennie. Premium nie ma limitów."),
                badge: L("Voice")
            )
        case .mealAIRefreshQuota:
            return Copy(
                headline: L("Limit odświeżeń AI wykorzystany"),
                body: L(
                    "W bezpłatnej wersji możesz odświeżyć dane dania 3 razy dziennie. Premium odblokowuje nielimitowane poprawki."
                ),
                badge: L("AI refresh")
            )
        case .productNutritionQuota:
            return Copy(
                headline: L("Limit produktów AI wykorzystany"),
                body: L("W bezpłatnej wersji AI uzupełni 2 pojedyncze produkty dziennie. Premium nie ma limitów."),
                badge: L("Produkty")
            )
        case .olaChefQuota:
            return Copy(
                headline: L("Kuchnia Oli bez limitu w Pro"),
                body: L("W bezpłatnej wersji Kuchnia Oli działa raz dziennie. Premium odblokowuje nielimitowane pomysły pod kalorie."),
                badge: L("Kuchnia Oli")
            )
        case .coachDebriefQuota:
            return Copy(
                headline: L("Ola jest w Pro"),
                body: L(
                    "Free pokazuje podgląd. Pro odblokowuje porady Oli, fakty w kontekście i tygodniowe podsumowania."),
                badge: L("AI Coach")
            )
        case .favoritesUnavailable:
            return Copy(
                headline: L("Ulubione bez limitu"),
                body: L("Zapisuj regularne produkty i dodawaj je jednym tapnięciem bez limitów."),
                badge: L("Favorites")
            )
        case .customGoalsCap:
            return Copy(
                headline: L("Więcej celów = Premium"),
                body: L("W bezpłatnej wersji jeden aktywny cel. Premium pozwala mieć trzy jednocześnie."),
                badge: L("Goals")
            )
        case .friendsCap:
            return Copy(
                headline: L("Znajomi bez limitu"),
                body: L("Dodawaj znajomych i grupy bez sztucznych ograniczeń."),
                badge: L("Społeczność")
            )
        case .recipesCap:
            return Copy(
                headline: L("Limit 5 przepisów"),
                body: L("W bezpłatnej wersji zapiszesz 5 przepisów. Pro odblokowuje całą bibliotekę i import z URL."),
                badge: L("Recipes")
            )
        case .exportCsv, .exportZip:
            return Copy(
                headline: L("Eksport bez limitu"),
                body: L("JSON, CSV i pełny ZIP są dostępne dla każdego użytkownika."),
                badge: L("Eksport")
            )
        case .themePicker:
            return Copy(
                headline: L("Wybór motywu — Premium"),
                body: L("Tryb ciemny, jasny albo automatyczny. Premium pozwala ustawić sztywno."),
                badge: L("Motyw")
            )
        case .iCloudSync:
            return Copy(
                headline: L("Synchronizacja przez iCloud — Premium"),
                body: L("Dane między telefonem a iPadem zawsze świeże. Premium włącza iCloud sync."),
                badge: L("Sync")
            )
        case .goalTracking:
            return Copy(
                headline: L("Śledzenie celu — Premium"),
                body: L("Daily weight, trend chart, and reminder. Premium unlocks full progress tracking."),
                badge: L("Goal")
            )
        case .manual:
            return Copy(
                headline: L("Wypróbuj Mealgram Premium"),
                body: L("7 dni za darmo. Pełne AI, nieograniczone skany, AI Coach, eksporty."),
                badge: nil
            )
        }
    }
}
