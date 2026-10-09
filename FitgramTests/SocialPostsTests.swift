import XCTest

@testable import Fitgram

final class PostContentPolicyTests: XCTestCase {
    func testCleanPostPasses() {
        XCTAssertEqual(
            PostContentPolicy.violations(title: "Pierwszy tydzień w celu", body: "6 z 7 dni w kaloriach 💪🏽"), [])
        XCTAssertEqual(PostContentPolicy.violations(title: "Тиждень у цілі", body: "Тебе теж вдасться!"), [])
    }

    func testLengthLimits() {
        XCTAssertTrue(PostContentPolicy.violations(title: "ab", body: "").contains(.titleTooShort))
        let longTitle = String(repeating: "a b ", count: 20)
        XCTAssertTrue(PostContentPolicy.violations(title: longTitle, body: "").contains(.titleTooLong))
        let longBody = String(repeating: "ok. ", count: 130)
        XCTAssertTrue(PostContentPolicy.violations(title: "Tytuł", body: longBody).contains(.bodyTooLong))
        XCTAssertTrue(PostContentPolicy.violations(title: "Ty\ntuł", body: "").contains(.titleMultiline))
    }

    func testProfanityAcrossLanguagesAndDisguises() {
        for text in [
            "kurwa", "K.U.R.W.A", "f*ck this", "fuuuuck", "sh1t", "ты хуй", "ПИЗДЕЦ", "puta madre", "zajebisty",
        ] {
            XCTAssertTrue(PostContentPolicy.containsProfanity(text), text)
        }
    }

    func testInnocentWordsAreNotFlagged() {
        for text in [
            "Тебе сподобається", "небалансированный рацион", "Херсон", "computadora", "disputa", "cono de helado",
            "Scunthorpe", "As w rękawie", "Classic pasta", "shiitake z ryżem",
        ] {
            XCTAssertFalse(PostContentPolicy.containsProfanity(text), text)
        }
    }

    func testLinksAndCharacters() {
        XCTAssertTrue(PostContentPolicy.containsLink("wejdź na promo.com"))
        XCTAssertTrue(PostContentPolicy.containsLink("https://x.y"))
        XCTAssertFalse(PostContentPolicy.containsLink("Dzień 1. Śniadanie."))
        XCTAssertTrue(PostContentPolicy.hasForbiddenCharacters("a\u{0007}b"))
        XCTAssertTrue(PostContentPolicy.hasForbiddenCharacters("z\u{0301}\u{0302}\u{0303}algo"))
        XCTAssertTrue(PostContentPolicy.hasForbiddenCharacters("zero\u{200B}width"))
        XCTAssertFalse(PostContentPolicy.hasForbiddenCharacters("Zażółć gęślą jaźń 👩‍👩‍👧 ❤️"))
        XCTAssertTrue(PostContentPolicy.hasLongRepeatedRun("Super!!!!!!!!"))
        XCTAssertFalse(PostContentPolicy.hasLongRepeatedRun("Super!!!"))
    }
}

final class UsernamePolicyTests: XCTestCase {
    func testValidUsernames() {
        for name in ["anna", "anna.kowalska", "kasia_99", "@Piotr.K", "abc"] {
            XCTAssertNil(UsernamePolicy.problem(for: name), name)
        }
        XCTAssertEqual(UsernamePolicy.normalize("  @Piotr.K "), "piotr.k")
    }

    func testInvalidUsernames() {
        XCTAssertEqual(UsernamePolicy.problem(for: "ab"), .tooShort)
        XCTAssertEqual(UsernamePolicy.problem(for: String(repeating: "a", count: 21)), .tooLong)
        XCTAssertEqual(UsernamePolicy.problem(for: "1anna"), .mustStartWithLetter)
        XCTAssertEqual(UsernamePolicy.problem(for: "anna-k"), .invalidCharacters)
        XCTAssertEqual(UsernamePolicy.problem(for: "żaneta"), .invalidCharacters)
        XCTAssertEqual(UsernamePolicy.problem(for: "anna..k"), .doubleSeparator)
        XCTAssertEqual(UsernamePolicy.problem(for: "anna_"), .endsWithSeparator)
        XCTAssertEqual(UsernamePolicy.problem(for: "admin"), .reserved)
        XCTAssertEqual(UsernamePolicy.problem(for: "fitgram.pl"), .reserved)
        XCTAssertEqual(UsernamePolicy.problem(for: "kurwa_mac"), .profanity)
    }

    func testSuggestionAndPlaceholder() {
        XCTAssertEqual(UsernamePolicy.suggestion(from: "Anna Kowalska"), "anna.kowalska")
        XCTAssertEqual(UsernamePolicy.suggestion(from: "Łukasz Żółć"), "lukasz.zolc")
        XCTAssertTrue(UsernamePolicy.isPlaceholder("mg1a2b3c4d5e"))
        XCTAssertFalse(UsernamePolicy.isPlaceholder("michal"))
    }
}

@MainActor
final class SocialPostsServiceTests: XCTestCase {
    private let me = "debug-user-001"
    private var author: PublicProfile {
        PublicProfile(
            id: me, displayName: "Ja", avatarURL: nil, sharesStreak: false, sharesAchievements: false,
            currentStreak: nil, achievementCount: nil, username: "ja.test", isPremium: true)
    }

    private func draft(_ title: String = "Mój dzień") -> PostDraft {
        PostDraft(title: title, body: "Opis", photoJPEG: nil, macros: nil)
    }

    func testOnlyPremiumCanPost() async throws {
        let service = InMemoryPostService(seeded: false)
        do {
            _ = try await service.create(draft(), as: author, isPremium: false)
            XCTFail("free users must not post")
        } catch let error as PostError {
            XCTAssertEqual(error, .premiumRequired)
        }
    }

    func testDailyLimitIsSeven() async throws {
        let service = InMemoryPostService(seeded: false)
        for index in 1...PostLimits.dailyMax {
            _ = try await service.create(draft("Post nr \(index)"), as: author, isPremium: true)
        }
        do {
            _ = try await service.create(draft("Ósmy post"), as: author, isPremium: true)
            XCTFail("8th post must be rejected")
        } catch let error as PostError {
            XCTAssertEqual(error, .dailyLimitReached)
        }
        let count = try await service.postCount(by: me, on: Date(), calendar: .current)
        XCTAssertEqual(count, 7)
    }

    func testDayBoundaryResetsTheLimit() async throws {
        var clock = Date()
        let service = InMemoryPostService(seeded: false, now: { clock })
        for index in 1...PostLimits.dailyMax {
            _ = try await service.create(draft("Post nr \(index)"), as: author, isPremium: true)
        }
        clock = Calendar.current.date(byAdding: .day, value: 1, to: clock) ?? clock
        _ = try await service.create(draft("Nowy dzień"), as: author, isPremium: true)
    }

    func testProfanityIsRejected() async throws {
        let service = InMemoryPostService(seeded: false)
        do {
            _ = try await service.create(draft("Ale kurwa dzień"), as: author, isPremium: true)
            XCTFail("profanity must be rejected")
        } catch let error as PostError {
            XCTAssertEqual(error, .contentRejected)
        }
    }

    func testLikeToggleCountsOncePerUser() async throws {
        let service = InMemoryPostService()
        let feed = try await service.feed(authorIDs: ["friend-ola"], viewer: me, limit: 10)
        let post = try XCTUnwrap(feed.first)
        XCTAssertEqual(post.likeCount, 3)
        XCTAssertFalse(post.isLikedByMe)

        try await service.setLiked(true, postID: post.id, viewer: me)
        try await service.setLiked(true, postID: post.id, viewer: me)
        var reloaded = try await service.feed(authorIDs: ["friend-ola"], viewer: me, limit: 10)
        XCTAssertEqual(reloaded.first?.likeCount, 4)
        XCTAssertEqual(reloaded.first?.isLikedByMe, true)

        try await service.setLiked(false, postID: post.id, viewer: me)
        reloaded = try await service.feed(authorIDs: ["friend-ola"], viewer: me, limit: 10)
        XCTAssertEqual(reloaded.first?.likeCount, 3)
        XCTAssertEqual(reloaded.first?.isLikedByMe, false)
    }

    func testFeedOnlyHasRequestedAuthorsNewestFirst() async throws {
        let service = InMemoryPostService()
        let feed = try await service.feed(authorIDs: ["friend-ola", "friend-ania-demo"], viewer: me, limit: 10)
        XCTAssertEqual(Set(feed.map(\.authorID)), ["friend-ola", "friend-ania-demo"])
        XCTAssertEqual(feed.map(\.createdAt), feed.map(\.createdAt).sorted(by: >))
    }

    func testOnlyAuthorCanDelete() async throws {
        let service = InMemoryPostService()
        let olaFeed = try await service.feed(authorIDs: ["friend-ola"], viewer: me, limit: 1)
        let olaPost = try XCTUnwrap(olaFeed.first)
        do {
            try await service.delete(postID: olaPost.id, as: me)
            XCTFail("can't delete someone else's post")
        } catch {}
        let mine = try await service.create(draft(), as: author, isPremium: true)
        try await service.delete(postID: mine.id, as: me)
        XCTAssertFalse(service.contains(postID: mine.id))
    }

    func testClosedProfilePostsFollowTheFriendGraph() async throws {
        let friends = InMemoryFriendService(seedFor: me)
        let posts = InMemoryPostService()
        posts.visibilityRule = { author, viewer in friends.canViewPosts(of: author, viewer: viewer) }

        let zosia = try await posts.posts(by: "friend-zosia-private", viewer: me)
        XCTAssertTrue(zosia.isHidden)
        let piotr = try await posts.posts(by: "friend-piotr-open", viewer: me)
        XCTAssertFalse(piotr.isHidden)
        XCTAssertEqual(piotr.posts.count, 1)

        let request = try await friends.sendRequest(from: me, to: "friend-zosia-private")
        try await friends.accept(request: request, as: "friend-zosia-private")
        let afterAccept = try await posts.posts(by: "friend-zosia-private", viewer: me)
        XCTAssertFalse(afterAccept.isHidden)
        XCTAssertEqual(afterAccept.posts.count, 1)
    }

    func testServerErrorMapping() {
        XCTAssertEqual(SupabasePostService.mapServerError(#"{"message":"daily_post_limit"}"#), .dailyLimitReached)
        XCTAssertEqual(SupabasePostService.mapServerError(#"{"message":"premium_required"}"#), .premiumRequired)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw") ?? .current
        let date = ISO8601DateFormatter().date(from: "2026-10-09T22:30:00Z") ?? Date()
        XCTAssertEqual(SupabasePostService.dayString(date, calendar: calendar), "2026-10-10")
    }
}

@MainActor
final class UsernameSearchTests: XCTestCase {
    private let me = "debug-user-001"

    func testSearchFindsPeopleByUsername() async throws {
        let service = InMemoryFriendService()
        let byHandle = try await service.search(query: "@ania.fit", excluding: me)
        XCTAssertEqual(byHandle.map(\.id), ["friend-ania-demo"])
        XCTAssertEqual(byHandle.first?.username, "ania.fit")
        XCTAssertEqual(byHandle.first?.isPremium, true)

        let partial = try await service.search(query: "PIOTR", excluding: me)
        XCTAssertEqual(partial.map(\.id), ["friend-piotr-open"])

        let underscore = try await service.search(query: "kasia_zd", excluding: me)
        XCTAssertEqual(underscore.map(\.id), ["friend-kasia"])

        let none = try await service.search(query: "@nobody.here", excluding: me)
        XCTAssertTrue(none.isEmpty)
    }

    func testSearchHidesBlockedPeople() async throws {
        let service = InMemoryFriendService()
        try await service.block("friend-piotr-open", as: me)
        let results = try await service.search(query: "piotr", excluding: me)
        XCTAssertTrue(results.isEmpty)
    }

    func testProfileForCodeResolvesUsername() async throws {
        let service = InMemoryFriendService()
        let profile = try await service.profile(forCode: "@Zosia.W")
        XCTAssertEqual(profile.id, "friend-zosia-private")
    }

    func testStrangerSnapshotsHonourVisibility() async throws {
        let service = InMemoryFriendService()
        let open = try await service.snapshot(forUserID: "friend-piotr-open", viewer: me)
        XCTAssertFalse(open.isRestricted)
        XCTAssertNotNil(open.weeklyStats)
        XCTAssertTrue(open.isPremium)

        let closed = try await service.snapshot(forUserID: "friend-zosia-private", viewer: me)
        XCTAssertTrue(closed.isRestricted)
        XCTAssertNil(closed.weeklyStats)
        XCTAssertNil(closed.bio)
        XCTAssertEqual(closed.username, "@zosia.w")
    }

    func testIncomingRequestCarriesSenderProfile() async throws {
        let service = InMemoryFriendService()
        let incoming = try await service.pendingIncoming(for: me)
        let request = try XCTUnwrap(incoming.first)
        XCTAssertEqual(request.counterpart?.displayName, "Nina")
        XCTAssertEqual(request.counterpart?.username, "nina")
    }

    func testUsernameClaimIsOneTime() async throws {
        let service = InMemorySocialProfileService()
        let available = try await service.isUsernameAvailable("ania.fit")
        XCTAssertFalse(available, "demo usernames are taken")
        try await service.claimUsername("@Nowa.Osoba", displayName: "Nowa", userID: "u1")
        let chosen = try await service.chosenUsername(userID: "u1")
        XCTAssertEqual(chosen, "nowa.osoba")
        // Same name again is a no-op; a different one is refused.
        try await service.claimUsername("nowa.osoba", displayName: nil, userID: "u1")
        do {
            try await service.claimUsername("inna.nazwa", displayName: nil, userID: "u1")
            XCTFail("username must be locked")
        } catch let error as UsernameClaimError {
            XCTAssertEqual(error, .locked)
        }
        do {
            try await service.claimUsername("nowa.osoba", displayName: nil, userID: "u2")
            XCTFail("username must be unique")
        } catch let error as UsernameClaimError {
            XCTAssertEqual(error, .taken)
        }
    }
}

@MainActor
final class FriendsStatePostsTests: XCTestCase {
    private let me = "debug-user-001"

    private func makeState() -> FriendsState {
        let friends = InMemoryFriendService(seedFor: me)
        let posts = InMemoryPostService()
        posts.visibilityRule = { author, viewer in friends.canViewPosts(of: author, viewer: viewer) }
        return FriendsState(
            service: friends,
            postService: posts,
            socialProfile: InMemorySocialProfileService(),
            userRemoteID: me,
            achievementCounters: AchievementCounterStore(defaults: UserDefaults(suiteName: "fs-\(UUID())") ?? .standard)
        )
    }

    func testRefreshLoadsFriendsPostsButNotStrangers() async {
        let state = makeState()
        await state.refresh()
        XCTAssertTrue(state.postsLoaded)
        XCTAssertFalse(state.posts.isEmpty)
        XCTAssertFalse(state.posts.contains { $0.authorID == "friend-piotr-open" })
        XCTAssertEqual(state.connectionStatus(for: "friend-nina"), .incoming)
        XCTAssertEqual(state.connectionStatus(for: "friend-ola"), .friend)
        XCTAssertEqual(state.connectionStatus(for: "friend-piotr-open"), .none)
    }

    func testToggleLikeUpdatesCountOptimistically() async throws {
        let state = makeState()
        await state.refresh()
        let post = try XCTUnwrap(state.posts.first)
        await state.toggleLike(post)
        XCTAssertEqual(state.posts.first?.likeCount, post.likeCount + 1)
        XCTAssertEqual(state.posts.first?.isLikedByMe, true)
        let liked = try XCTUnwrap(state.posts.first)
        await state.toggleLike(liked)
        XCTAssertEqual(state.posts.first?.likeCount, post.likeCount)
    }

    func testPublishRequiresPremiumAndCountsTowardsLimit() async throws {
        let state = makeState()
        state.myDisplayName = "Ja"
        await state.refresh()
        do {
            try await state.publish(PostDraft(title: "Mój post", body: "", photoJPEG: nil, macros: nil))
            XCTFail("free user must not publish")
        } catch {}
        await state.setPremium(true)
        try await state.publish(PostDraft(title: "Mój post", body: "", photoJPEG: nil, macros: nil))
        XCTAssertEqual(state.posts.first?.authorID, me)
        XCTAssertEqual(state.posts.first?.authorIsPremium, true)
        XCTAssertEqual(state.postsPublishedToday, 1)
        XCTAssertEqual(state.postsLeftToday, PostLimits.dailyMax - 1)
    }

    func testSendRequestFromSearchedProfile() async {
        let state = makeState()
        await state.refresh()
        state.searchQuery = "@piotr.k"
        await state.runSearch()
        XCTAssertEqual(state.searchResults.map(\.id), ["friend-piotr-open"])
        let sent = await state.sendRequest(to: "friend-piotr-open")
        XCTAssertTrue(sent)
        // The in-memory backend auto-accepts, so Piotr is now a friend.
        XCTAssertEqual(state.connectionStatus(for: "friend-piotr-open"), .friend)
    }

    func testIdentityClaimsLocalUsernameWhenServerHasNone() async {
        let state = makeState()
        let chosen = await state.loadIdentity(localUsername: "moja.nazwa")
        XCTAssertEqual(chosen, "moja.nazwa")
        XCTAssertEqual(state.myUsername, "moja.nazwa")
        XCTAssertFalse(state.needsUsername)

        let fresh = makeState()
        _ = await fresh.loadIdentity(localUsername: nil)
        XCTAssertTrue(fresh.needsUsername)
    }
}

@MainActor
final class SocialPrivacyAndMacrosTests: XCTestCase {
    func testLegacyPrivacyJSONStillDecodes() throws {
        let legacy =
            #"{"visibility":"friends","showStreak":true,"showLevel":false,"showAchievements":true,"#
            + #""showGoal":false,"showWeeklyStats":false,"showRecipes":false,"showWeightAndHeight":false,"#
            + #""showMealDetails":false}"#
        let decoded = try JSONDecoder().decode(PrivacySettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(decoded.visibility, .friendsOnly)
        XCTAssertTrue(decoded.showStreak)
        XCTAssertEqual(decoded.postsVisibility, .friends)
    }

    func testPrivacyRowRoundTrip() {
        var settings = PrivacySettings()
        settings.visibility = .publicLink
        settings.postsVisibility = .everyone
        settings.showGoal = true
        let row = PrivacyRow(settings: settings, userID: "u")
        XCTAssertEqual(row.postsVisibility, "public")
        XCTAssertEqual(row.settings, settings)
    }

    func testMacroSnapshotsForDayAndMeal() {
        let breakfast = MealEntry(
            mealType: .breakfast, source: .manual,
            items: [
                FoodItem(
                    name: "Owsianka", quantityGrams: 250, caloriesKcal: 350, proteinGrams: 12, carbsGrams: 55,
                    fatGrams: 8),
                FoodItem(
                    name: "Banan", quantityGrams: 120, caloriesKcal: 105, proteinGrams: 1, carbsGrams: 27, fatGrams: 0),
            ])
        let lunch = MealEntry(
            mealType: .lunch, source: .manual, portionMultiplier: 2,
            items: [
                FoodItem(
                    name: "Kurczak", quantityGrams: 150, caloriesKcal: 250, proteinGrams: 45, carbsGrams: 0, fatGrams: 6
                )
            ])
        let day = PostMacroBuilder.day([breakfast, lunch], goalKcal: 2000)
        XCTAssertEqual(day?.scope, .day)
        XCTAssertEqual(day?.kcal, 955)
        XCTAssertEqual(day?.proteinG, 103)
        XCTAssertEqual(day?.mealCount, 2)
        XCTAssertEqual(day?.goalKcal, 2000)
        XCTAssertEqual(day?.items.first, "Kurczak")

        let meal = PostMacroBuilder.meal(lunch, goalKcal: 0)
        XCTAssertEqual(meal.scope, .meal)
        XCTAssertEqual(meal.kcal, 500)
        XCTAssertNil(meal.goalKcal)
        XCTAssertNil(PostMacroBuilder.day([], goalKcal: 2000))
    }

    func testMacroSnapshotEncodesForPostgres() throws {
        let snapshot = PostMacroSnapshot(
            scope: .meal, label: "Obiad", consumedAt: Date(timeIntervalSince1970: 1_800_000_000), kcal: 600,
            proteinG: 40, carbsG: 60, fatG: 20, goalKcal: 2000, items: ["Ryż"], mealCount: 1)
        let data = try JSONEncoder.fitgram.encode(snapshot)
        let json = String(bytes: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"protein_g\":40"))
        XCTAssertTrue(json.contains("\"consumed_at\""))
        let decoded = try JSONDecoder.fitgram.decode(PostMacroSnapshot.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }
}
