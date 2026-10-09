import XCTest

@testable import Fitgram

final class PostPluralTests: XCTestCase {
    func testPolishAndRussianPlurals() {
        let polish = { (count: Int) in
            PostCard.plural(count, one: "polubienie", few: "polubienia", many: "polubień", eastSlavic: false)
        }
        XCTAssertEqual(polish(1), "polubienie")
        XCTAssertEqual(polish(3), "polubienia")
        XCTAssertEqual(polish(5), "polubień")
        XCTAssertEqual(polish(12), "polubień")
        XCTAssertEqual(polish(21), "polubień")
        XCTAssertEqual(polish(22), "polubienia")
        let russian = { (count: Int) in
            PostCard.plural(count, one: "лайк", few: "лайка", many: "лайков", eastSlavic: true)
        }
        XCTAssertEqual(russian(1), "лайк")
        XCTAssertEqual(russian(2), "лайка")
        XCTAssertEqual(russian(11), "лайков")
        XCTAssertEqual(russian(21), "лайк")
        XCTAssertEqual(russian(0), "лайков")
    }
}

@MainActor
final class PostActivityTests: XCTestCase {
    private let me = "debug-user-001"
    private var author: PublicProfile {
        PublicProfile(
            id: me, displayName: "Ja", avatarURL: nil, sharesStreak: false, sharesAchievements: false,
            currentStreak: nil, achievementCount: nil, username: "ja.test", isPremium: true)
    }

    private var run: PostActivitySnapshot {
        PostActivitySnapshot(
            name: "Bieg", symbol: "figure.run", startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            durationMinutes: 42, kcalBurned: 460, distanceMeters: 7_300, steps: 8_900, averageHeartRate: 152)
    }

    private var macros: PostMacroSnapshot {
        PostMacroSnapshot(
            scope: .day, label: nil, consumedAt: Date(), kcal: 1800, proteinG: 120, carbsG: 200, fatG: 60,
            goalKcal: 2000, items: [], mealCount: 3)
    }

    func testPostCarriesAnActivity() async throws {
        let service = InMemoryPostService(seeded: false)
        let post = try await service.create(
            PostDraft(title: "Poranny bieg", body: "", photoJPEG: nil, macros: nil, activity: run),
            as: author, isPremium: true)
        XCTAssertEqual(post.activity, run)
        XCTAssertNil(post.macros)
    }

    func testMacrosAndActivityTogetherAreRejected() async throws {
        let service = InMemoryPostService(seeded: false)
        do {
            _ = try await service.create(
                PostDraft(title: "Wszystko naraz", body: "", photoJPEG: nil, macros: macros, activity: run),
                as: author, isPremium: true)
            XCTFail("only one attachment is allowed")
        } catch let error as PostError {
            XCTAssertEqual(error, .oneAttachmentOnly)
        }
        XCTAssertEqual(
            SupabasePostService.mapServerError(#"violates check constraint "posts_one_attachment""#),
            .oneAttachmentOnly)
    }

    func testActivitySnapshotFromWorkout() {
        let workout = WorkoutEntry(
            userRemoteID: me, activityID: "run_easy", activityName: "Bieg", durationMinutes: 30, met: 8,
            caloriesBurnedKcal: 312.6, distanceMeters: 0, steps: 4200, averageHeartRateBpm: 141.4)
        let snapshot = PostActivityBuilder.activity(workout)
        XCTAssertEqual(snapshot.symbol, "figure.run")
        XCTAssertEqual(snapshot.kcalBurned, 313)
        XCTAssertNil(snapshot.distanceMeters, "zero distance is dropped")
        XCTAssertEqual(snapshot.steps, 4200)
        XCTAssertEqual(snapshot.averageHeartRate, 141)
    }

    func testActivityEncodesForPostgres() throws {
        let data = try JSONEncoder.fitgram.encode(run)
        let json = String(bytes: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("\"duration_minutes\":42"))
        XCTAssertEqual(try JSONDecoder.fitgram.decode(PostActivitySnapshot.self, from: data), run)
    }

    func testSeededOpenProfileSharesARun() async throws {
        let service = InMemoryPostService()
        let piotr = try await service.posts(by: "friend-piotr-open", viewer: me)
        XCTAssertEqual(piotr.posts.first?.activity?.symbol, "figure.run")
    }
}
