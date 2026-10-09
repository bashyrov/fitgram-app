import Foundation

// Demo posts written by the seeded friends of `InMemoryFriendService`.
extension InMemoryPostService {
    static func seedPosts(now: Date) -> (posts: [SocialPost], likes: [UUID: Set<String>]) {
        let testPost = testPost(now: now)
        let aniaPost = aniaPost(now: now)
        let martaPost = martaPost(now: now)
        let olaPost = olaPost(now: now)
        let strangers = strangerPosts(now: now)
        let likes: [UUID: Set<String>] = [
            strangers[0].id: ["friend-ola"],
            testPost.id: ["friend-ania-demo", "friend-marta-demo", "friend-ola", "friend-kasia"],
            aniaPost.id: ["friend-fitgram-test", "friend-kasia"],
            martaPost.id: ["friend-ania-demo"],
            olaPost.id: ["friend-michal", "friend-kasia", "friend-ania-demo"],
        ]
        return ([testPost, aniaPost, martaPost, olaPost] + strangers, likes)
    }

    /// Posts of the open (Piotr) and closed (Zosia) non-friend profiles.
    private static func strangerPosts(now: Date) -> [SocialPost] {
        let hour: TimeInterval = 3600
        let piotrPost = SocialPost(
            id: UUID(),
            authorID: "friend-piotr-open",
            authorName: "Piotr Kowalczyk",
            authorUsername: "piotr.k",
            authorIsPremium: true,
            title: TL(
                pl: "Minus 6 kg od lutego", en: "Down 6 kg since February", uk: "Мінус 6 кг з лютого",
                ru: "Минус 6 кг с февраля", es: "6 kg menos desde febrero"),
            body: TL(
                pl: "Bez cudów: deficyt 400 kcal, dużo białka i spacery po pracy.",
                en: "No miracles: a 400 kcal deficit, plenty of protein and walks after work.",
                uk: "Без чудес: дефіцит 400 ккал, багато білка й прогулянки після роботи.",
                ru: "Без чудес: дефицит 400 ккал, много белка и прогулки после работы.",
                es: "Sin milagros: déficit de 400 kcal, mucha proteína y paseos después del trabajo."),
            photoURL: nil,
            macros: nil,
            activity: PostActivitySnapshot(
                name: TL(pl: "Bieg", en: "Run", uk: "Біг", ru: "Бег", es: "Carrera"), symbol: "figure.run",
                startedAt: now.addingTimeInterval(-27 * hour), durationMinutes: 42, kcalBurned: 460,
                distanceMeters: 7_300, steps: 8_900, averageHeartRate: 152),
            createdAt: now.addingTimeInterval(-26 * hour),
            likeCount: 0,
            isLikedByMe: false
        )
        let zosiaPost = SocialPost(
            id: UUID(),
            authorID: "friend-zosia-private",
            authorName: "Zosia",
            authorUsername: "zosia.w",
            authorIsPremium: true,
            title: "Meal prep na tydzień",
            body: "",
            photoURL: nil,
            macros: nil,
            createdAt: now.addingTimeInterval(-50 * hour),
            likeCount: 0,
            isLikedByMe: false
        )
        return [piotrPost, zosiaPost]
    }

    private static func testPost(now: Date) -> SocialPost {
        let hour: TimeInterval = 3600
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        return SocialPost(
            id: UUID(),
            authorID: "friend-fitgram-test",
            authorName: "Fitgram Test",
            authorUsername: "fitgram_test",
            authorIsPremium: true,
            title: TL(
                pl: "Białko domknięte przed kolacją", en: "Protein goal closed before dinner",
                uk: "Білок закрито до вечері", ru: "Белок закрыт до ужина", es: "Proteína cerrada antes de la cena"),
            body: TL(
                pl: "Skyr rano, kurczak z ryżem na obiad i bez podjadania. 47 dni serii!",
                en: "Skyr in the morning, chicken and rice for lunch, no snacking. 47-day streak!",
                uk: "Скір зранку, курка з рисом на обід і без перекусів. Серія 47 днів!",
                ru: "Скир утром, курица с рисом на обед и без перекусов. Серия 47 дней!",
                es: "Skyr por la mañana, pollo con arroz a mediodía y sin picar. ¡Racha de 47 días!"),
            photoURL: nil,
            macros: PostMacroSnapshot(
                scope: .day, label: nil, consumedAt: now.addingTimeInterval(-2 * hour), kcal: 2050, proteinG: 168,
                carbsG: 190, fatG: 62, goalKcal: 2100,
                items: ["Kurczak z ryżem", "Skyr z malinami", "Owsianka", "Jabłko"], mealCount: 4),
            createdAt: now.addingTimeInterval(-40 * 60),
            likeCount: 0,
            isLikedByMe: false
        )
    }

    private static func aniaPost(now: Date) -> SocialPost {
        let hour: TimeInterval = 3600
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        return SocialPost(
            id: UUID(),
            authorID: "friend-ania-demo",
            authorName: "Ania",
            authorUsername: "ania.fit",
            authorIsPremium: true,
            title: TL(
                pl: "Łosoś teriyaki — 610 kcal", en: "Salmon teriyaki — 610 kcal", uk: "Лосось теріякі — 610 ккал",
                ru: "Лосось терияки — 610 ккал", es: "Salmón teriyaki: 610 kcal"),
            body: TL(
                pl: "Najlepszy obiad tygodnia. Przepis wrzucam do książki kucharskiej.",
                en: "Best lunch of the week. Adding the recipe to my cookbook.",
                uk: "Найкращий обід тижня. Рецепт додаю в книгу рецептів.",
                ru: "Лучший обед недели. Рецепт добавляю в книгу рецептов.",
                es: "La mejor comida de la semana. Añado la receta a mi recetario."),
            photoURL: nil,
            macros: PostMacroSnapshot(
                scope: .meal, label: L("Obiad"), consumedAt: now.addingTimeInterval(-5 * hour), kcal: 610,
                proteinG: 42, carbsG: 64, fatG: 18, goalKcal: 1800,
                items: ["Łosoś", "Ryż jaśminowy", "Brokuły", "Sos teriyaki"], mealCount: 1),
            createdAt: now.addingTimeInterval(-3 * hour),
            likeCount: 0,
            isLikedByMe: false
        )
    }

    private static func martaPost(now: Date) -> SocialPost {
        let hour: TimeInterval = 3600
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        return SocialPost(
            id: UUID(),
            authorID: "friend-marta-demo",
            authorName: "Marta Demo",
            authorUsername: "marta_fit",
            authorIsPremium: true,
            title: TL(
                pl: "Pierwszy tydzień w celu", en: "First full week on target", uk: "Перший тиждень у цілі",
                ru: "Первая неделя в цели", es: "Primera semana dentro del objetivo"),
            body: TL(
                pl: "6 z 7 dni w kaloriach. Weekend był trudny, ale się udało 💪",
                en: "6 out of 7 days within calories. The weekend was tough, but I made it 💪",
                uk: "6 із 7 днів у калоріях. Вихідні були важкі, але вийшло 💪",
                ru: "6 из 7 дней в калориях. Выходные были тяжёлыми, но получилось 💪",
                es: "6 de 7 días dentro de las calorías. El fin de semana costó, pero lo logré 💪"),
            photoURL: nil,
            macros: nil,
            createdAt: yesterday.addingTimeInterval(-hour),
            likeCount: 0,
            isLikedByMe: false
        )
    }

    private static func olaPost(now: Date) -> SocialPost {
        let hour: TimeInterval = 3600
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now
        return SocialPost(
            id: UUID(),
            authorID: "friend-ola",
            authorName: "Ola",
            authorUsername: "ola_k",
            authorIsPremium: true,
            title: TL(
                pl: "Wege dzień bez spiny", en: "Easy veggie day", uk: "Веганський день без стресу",
                ru: "Веган-день без стресса", es: "Día vegetariano sin estrés"),
            body: TL(
                pl: "Tofu, ciecierzyca i dużo warzyw. Białko wyszło lepiej niż myślałam.",
                en: "Tofu, chickpeas and lots of veg. Protein came out better than I expected.",
                uk: "Тофу, нут і багато овочів. Білка вийшло більше, ніж думала.",
                ru: "Тофу, нут и много овощей. Белка вышло больше, чем думала.",
                es: "Tofu, garbanzos y muchas verduras. Salió más proteína de la que esperaba."),
            photoURL: nil,
            macros: PostMacroSnapshot(
                scope: .day, label: nil, consumedAt: yesterday, kcal: 1790, proteinG: 104, carbsG: 210, fatG: 55,
                goalKcal: 1850, items: ["Tofu z warzywami", "Hummus", "Owsianka"], mealCount: 3),
            createdAt: yesterday.addingTimeInterval(-6 * hour),
            likeCount: 0,
            isLikedByMe: false
        )
    }
}
