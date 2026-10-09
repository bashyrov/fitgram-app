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
    case socialPosts = "social_posts"
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
            return Self.weeklyAIPoolCopy(badge: L("Skanowanie AI"))
        case .barcodeScanQuota:
            return Copy(
                headline: L("Limit skanowania wykorzystany"),
                body: L("W bezpłatnej wersji masz bardzo dużo miejsca na testy, a Pro daje jeszcze większy zapas."),
                badge: L("Kody")
            )
        case .voiceEntryQuota:
            return Self.weeklyAIPoolCopy(badge: L("Voice"))
        case .mealAIRefreshQuota:
            return Self.weeklyAIPoolCopy(badge: L("AI refresh"))
        case .productNutritionQuota:
            return Self.weeklyAIPoolCopy(badge: L("Produkty"))
        case .olaChefQuota:
            return Copy(
                headline: L("Kuchnia Oli z dużym limitem w Pro"),
                body: L(
                    """
                    W bezpłatnej wersji Kuchnia Oli korzysta najpierw z lokalnej biblioteki dań, a AI tylko dopina szczegóły. \
                    Premium daje bardzo duże limity i więcej AI.
                    """
                ),
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
                body: L(
                    "W bezpłatnej wersji zapiszesz 5 przepisów. Pro daje bardzo duże limity, całą bibliotekę i import z URL."
                ),
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
        case .socialPosts:
            return Copy(
                headline: TL(
                    pl: "Posty dla znajomych — Premium", en: "Posts for friends — Premium",
                    uk: "Пости для друзів — Premium", ru: "Посты для друзей — Premium",
                    es: "Publicaciones para amigos: Premium"),
                body: TL(
                    pl:
                        "Z Premium publikujesz do \(PostLimits.dailyMax) postów dziennie: tytuł, opis, zdjęcie i makro z dowolnego dnia. "
                        + "Przy Twoim imieniu pojawi się znaczek Premium.",
                    en:
                        "With Premium you can publish up to \(PostLimits.dailyMax) posts a day: "
                        + "title, description, photo and macros from any day. "
                        + "A Premium mark appears next to your name.",
                    uk:
                        "З Premium ти публікуєш до \(PostLimits.dailyMax) постів на день: заголовок, опис, фото й макро за будь-який день. "
                        + "Біля імені з'явиться значок Premium.",
                    ru:
                        "С Premium ты публикуешь до \(PostLimits.dailyMax) постов в день: заголовок, описание, фото и макро за любой день. "
                        + "Рядом с именем появится значок Premium.",
                    es:
                        "Con Premium publicas hasta \(PostLimits.dailyMax) veces al día: "
                        + "título, descripción, foto y macros de cualquier día. "
                        + "Junto a tu nombre aparecerá la marca Premium."
                ),
                badge: TL(pl: "Posty", en: "Posts", uk: "Пости", ru: "Посты", es: "Posts")
            )
        case .manual:
            return Copy(
                headline: L("Wypróbuj Fitgram Premium"),
                body: L("7 dni za darmo. Pełne AI, bardzo duże limity, AI Coach i eksporty."),
                badge: nil
            )
        }
    }

    /// Photo, voice, refresh and product lookups share one weekly free pool,
    /// so they share the copy too.
    private static func weeklyAIPoolCopy(badge: String) -> Copy {
        let cap = FreeTierLimits.aiActionsPerWeek ?? 0
        return Copy(
            headline: TL(
                pl: "Tygodniowy limit AI wykorzystany",
                en: "Weekly AI limit used up",
                uk: "Тижневий ліміт AI вичерпано",
                ru: "Недельный лимит ИИ исчерпан",
                es: "Has usado el límite semanal de AI"
            ),
            body: String.localizedStringWithFormat(
                TL(
                    pl: """
                        Bezpłatnie masz %lld działań AI tygodniowo — zdjęcia, głos i poprawki. Kody kreskowe, baza \
                        produktów i ręczne wpisy działają bez limitu. Pro zdejmuje limit AI — 7 dni za darmo.
                        """,
                    en: """
                        Free includes %lld AI actions a week — photos, voice and fixes. Barcodes, the food database \
                        and manual entries stay unlimited. Pro removes the AI limit — 7 days free.
                        """,
                    uk: """
                        Безкоштовно — %lld дій AI на тиждень: фото, голос і правки. Штрихкоди, база продуктів і \
                        ручні записи без ліміту. Pro знімає ліміт AI — 7 днів безкоштовно.
                        """,
                    ru: """
                        Бесплатно — %lld ИИ-действий в неделю: фото, голос и правки. Штрихкоды, база продуктов и \
                        ручной ввод без лимита. Pro снимает лимит ИИ — 7 дней бесплатно.
                        """,
                    es: """
                        Gratis tienes %lld acciones de AI por semana: fotos, voz y ajustes. Códigos de barras, la base \
                        de alimentos y las entradas manuales no tienen límite. Pro quita el límite de AI: 7 días gratis.
                        """
                ),
                cap
            ),
            badge: badge
        )
    }
}
