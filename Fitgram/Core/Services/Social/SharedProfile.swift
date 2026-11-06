import Foundation
import OSLog
import SwiftData

/// The part of a profile its owner chose to share (Privacy toggles), as
/// stored in `public.profile_shares`. Every field is optional: a field the
/// owner switched off is simply absent. Labels are rebuilt on the viewer's
/// device so they appear in the viewer's language.
struct SharedProfile: Codable, Equatable, Sendable {
    struct Goal: Codable, Equatable, Sendable {
        var kind: String
        var targetKg: Double?
        var startKg: Double?
        var endDate: Date?
    }

    struct Weekly: Codable, Equatable, Sendable {
        var averageDailyKcal: Int
        var totalScans: Int
        var daysHitGoal: Int
        var topFoods: [String]
    }

    struct Recipe: Codable, Equatable, Sendable {
        var id: UUID
        var name: String
        var kcalPerServing: Int?
        var cookCount: Int
    }

    var streak: Int?
    var level: Int?
    var achievementKinds: [String]?
    var goal: Goal?
    var weekly: Weekly?
    var recipes: [Recipe]?
    var weightKg: Double?
    var heightCm: Int?

    static let coder: (encoder: JSONEncoder, decoder: JSONDecoder) = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .secondsSince1970
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (encoder, decoder)
    }()
}

/// Builds the shared part of the signed-in account's profile from local data,
/// keeping only what `PrivacySettings` allows. Nil when the profile is
/// private, so nothing is published at all.
@MainActor
enum SharedProfileBuilder {
    static func build(
        owner: String, privacy: PrivacySettings, container: ModelContainer, now: Date = Date(),
        calendar: Calendar = .current
    ) -> SharedProfile? {
        guard privacy.visibility != .privateOnly else { return nil }
        let context = ModelContext(container)
        let user = try? context.fetch(FetchDescriptor<User>(predicate: #Predicate { $0.remoteID == owner })).first
        var shared = SharedProfile()

        if privacy.showStreak {
            let streak = try? context.fetch(
                FetchDescriptor<Streak>(predicate: #Predicate { $0.userRemoteID == owner })
            ).first
            shared.streak = streak?.currentLength ?? 0
        }
        if privacy.showAchievements || privacy.showLevel {
            let kinds =
                (try? context.fetch(FetchDescriptor<Achievement>(predicate: #Predicate { $0.userRemoteID == owner })))?
                .map(\.kind) ?? []
            if privacy.showAchievements { shared.achievementKinds = kinds.sorted() }
            if privacy.showLevel {
                shared.level = AchievementXP.progress(xp: AchievementXP.total(earnedIDs: kinds)).level
            }
        }
        if privacy.showGoal, let user {
            shared.goal = SharedProfile.Goal(
                kind: user.goalKindRaw, targetKg: user.goalTargetWeightKg,
                startKg: user.goalStartWeightKg ?? user.weightKg, endDate: user.goalEstimatedEndDate)
        }
        if privacy.showWeeklyStats {
            shared.weekly = weekly(
                owner: owner, goal: user?.dailyCalorieGoalKcal ?? 0, context: context, now: now, calendar: calendar)
        }
        if privacy.showRecipes {
            let recipes =
                (try? context.fetch(FetchDescriptor<Fitgram.Recipe>(predicate: #Predicate { $0.userRemoteID == owner })))
                ?? []
            shared.recipes =
                recipes
                .sorted { ($0.cookCount, $1.title) > ($1.cookCount, $0.title) }
                .prefix(3)
                .map {
                    SharedProfile.Recipe(
                        id: $0.id, name: $0.title, kcalPerServing: $0.caloriesPerServing.map { Int($0.rounded()) },
                        cookCount: $0.cookCount)
                }
        }
        if privacy.showWeightAndHeight {
            let latest = try? context.fetch(
                {
                    var descriptor = FetchDescriptor<WeightEntry>(
                        predicate: #Predicate { $0.userRemoteID == owner },
                        sortBy: [SortDescriptor(\WeightEntry.recordedAt, order: .reverse)])
                    descriptor.fetchLimit = 1
                    return descriptor
                }()
            ).first
            shared.weightKg = latest?.weightKg ?? user?.weightKg
            shared.heightCm = user?.heightCm
        }
        return shared
    }

    /// Last 7 days including today.
    private static func weekly(
        owner: String, goal: Int, context: ModelContext, now: Date, calendar: Calendar
    ) -> SharedProfile.Weekly {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let meals =
            (try? context.fetch(
                FetchDescriptor<MealEntry>(predicate: #Predicate { $0.userRemoteID == owner && $0.consumedAt >= start })
            ))
            ?? []
        var byDay: [Date: Double] = [:]
        var foods: [String: Int] = [:]
        for meal in meals {
            byDay[calendar.startOfDay(for: meal.consumedAt), default: 0] += meal.totalCaloriesKcal
            for item in meal.items where !item.name.isEmpty { foods[item.name, default: 0] += 1 }
        }
        let average = byDay.isEmpty ? 0 : Int((byDay.values.reduce(0, +) / Double(byDay.count)).rounded())
        let hit = goal > 0 ? byDay.values.filter { abs($0 - Double(goal)) <= Double(goal) * 0.15 }.count : 0
        let top = foods.sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(5).map(\.key)
        return SharedProfile.Weekly(
            averageDailyKcal: average, totalScans: meals.filter { $0.source == .photoScan }.count, daysHitGoal: hit,
            topFoods: top)
    }
}

/// Publishes the shared profile to Supabase: upserts it, or deletes the row
/// when the profile is private. Skips the upload when nothing changed.
@MainActor
final class SharedProfilePublisher {
    private let container: ModelContainer
    private let privacy: () -> PrivacySettings
    private let client: SupabaseRESTClient?
    private var lastPublished: [String: Data?] = [:]
    private var pending: Task<Void, Never>?

    init(
        container: ModelContainer, privacy: @escaping () -> PrivacySettings,
        client: SupabaseRESTClient? = SupabaseRESTClient(decoder: JSONDecoder(), encoder: JSONEncoder())
    ) {
        self.container = container
        self.privacy = privacy
        self.client = client
    }

    func requestPublish(owner: String, after delay: Duration = .seconds(2)) {
        pending?.cancel()
        pending = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.publish(owner: owner)
        }
    }

    func publish(owner: String) async {
        guard let client, !owner.isEmpty else { return }
        let shared = SharedProfileBuilder.build(owner: owner, privacy: privacy(), container: container)
        let payload = try? shared.map { try SharedProfile.coder.encoder.encode($0) }
        if let previous = lastPublished[owner], previous == payload { return }
        do {
            if let payload, let text = String(bytes: payload, encoding: .utf8) {
                try await client.request(
                    path: "profile_shares",
                    method: .post,
                    query: [URLQueryItem(name: "on_conflict", value: "user_id")],
                    body: ShareRow(userID: owner, payload: text),
                    prefer: "resolution=merge-duplicates,return=minimal"
                )
            } else {
                try await client.request(
                    path: "profile_shares", method: .delete,
                    query: [URLQueryItem(name: "user_id", value: "eq.\(owner)")], prefer: "return=minimal")
            }
            lastPublished[owner] = payload
        } catch SupabaseRESTClient.SupabaseError.unauthorized {
        } catch {
            Logger.auth.error("Publishing shared profile failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private struct ShareRow: Encodable {
    let userID: String
    let payload: String

    enum CodingKeys: String, CodingKey {
        case payload
        case userID = "user_id"
    }
}
